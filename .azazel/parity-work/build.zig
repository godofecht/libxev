const std = @import("std");
const spec = @import("build_spec.zig");
const builtin = @import("builtin");

fn laneMatchesCurrent(comptime lane: []const u8) bool {
    if (std.mem.eql(u8, lane, "0.14")) {
        return builtin.zig_version.major == 0 and builtin.zig_version.minor == 14;
    }
    if (std.mem.eql(u8, lane, "0.15")) {
        return builtin.zig_version.major == 0 and builtin.zig_version.minor == 15;
    }
    if (std.mem.eql(u8, lane, "0.16")) {
        return builtin.zig_version.major == 0 and builtin.zig_version.minor == 16;
    }
    return false;
}

fn supportsCurrentZig() bool {
    inline for (spec.toolchain.zig_lanes) |lane| {
        if (laneMatchesCurrent(lane)) return true;
    }
    return false;
}

comptime {
    if (!supportsCurrentZig()) {
        @compileError("unsupported Zig toolchain lane for this Azazel build spec; regenerate or run with a Zig lane declared in project.cue toolchain.zig.lanes");
    }
}

fn linkOf(name: []const u8) spec.Link {
    for (spec.modules) |m| {
        if (std.mem.eql(u8, m.name, name)) return m.link;
    }
    return .abi;
}

fn kindOf(name: []const u8) spec.Kind {
    for (spec.modules) |m| {
        if (std.mem.eql(u8, m.name, name)) return m.kind;
    }
    return .module;
}

fn addPostCommand(b: *std.Build, module_name: []const u8, index: usize, cmd: spec.Command) *std.Build.Step {
    const run = b.addSystemCommand(cmd.argv);
    run.stdio = .inherit;
    const step = b.step(
        b.fmt("{s}-post-{d}", .{ module_name, index }),
        b.fmt("Run post-build command {d} for {s}", .{ index, module_name }),
    );
    step.dependOn(&run.step);
    return step;
}

fn addCommand(b: *std.Build, module_name: []const u8, phase: []const u8, index: usize, cmd: spec.Command) *std.Build.Step {
    const run = b.addSystemCommand(cmd.argv);
    run.stdio = .inherit;
    const step = b.step(
        b.fmt("{s}-{s}-{d}", .{ module_name, phase, index }),
        b.fmt("Run {s} command {d} for {s}", .{ phase, index, module_name }),
    );
    step.dependOn(&run.step);
    return step;
}

fn findOption(name: []const u8) ?spec.Option {
    for (spec.options) |option| {
        if (std.mem.eql(u8, option.name, name)) return option;
    }
    return null;
}

fn addBuildOptions(b: *std.Build, module_name: []const u8, option_names: []const []const u8) ?*std.Build.Step.Options {
    if (option_names.len == 0) return null;

    const options = b.addOptions();
    for (option_names) |name| {
        const option = findOption(name) orelse @panic("module references unknown build option");
        switch (option.type) {
            .bool => {
                const value = b.option(bool, option.name, option.description) orelse (option.bool_default orelse false);
                options.addOption(bool, option.name, value);
            },
            .string => {
                const value = b.option([]const u8, option.name, option.description) orelse (option.string_default orelse "");
                options.addOption([]const u8, option.name, value);
            },
            .u32 => {
                const value = b.option(u32, option.name, option.description) orelse (option.u32_default orelse 0);
                options.addOption(u32, option.name, value);
            },
        }
    }

    _ = module_name;
    return options;
}

fn applyNative(b: *std.Build, mod: *std.Build.Module, native: spec.Native) void {
    if (native.link_libc) mod.link_libc = true;
    if (native.link_libcpp) mod.link_libcpp = true;

    for (native.c_sources) |src| {
        mod.addCSourceFile(.{ .file = b.path(src), .flags = &.{} });
    }
    for (native.include_dirs) |dir| {
        mod.addIncludePath(b.path(dir));
    }
    for (native.system_include_dirs) |dir| {
        mod.addSystemIncludePath(b.path(dir));
    }
    for (native.library_paths) |dir| {
        mod.addLibraryPath(b.path(dir));
    }
    for (native.object_files) |file| {
        mod.addObjectFile(b.path(file));
    }
    for (native.system_libs) |lib| {
        mod.linkSystemLibrary(lib, .{});
    }
    for (native.pkg_config_libs) |lib| {
        mod.linkSystemLibrary(lib, .{ .use_pkg_config = .force });
    }
    for (native.frameworks) |framework| {
        mod.linkFramework(framework, .{});
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // A Zig module for every declared module, and a compile step only for the
    // ones that become a real artifact. An `import` dependency is merged into
    // its dependents as a module, so it needs no artifact and no link step.
    var modules = std.StringHashMap(*std.Build.Module).init(b.allocator);
    var steps = std.StringHashMap(*std.Build.Step.Compile).init(b.allocator);
    defer modules.deinit();
    defer steps.deinit();

    for (spec.modules) |m| {
        // Zig 0.15 takes target and optimize on the module rather than on the
        // compile step, and folds addStaticLibrary/addSharedLibrary into
        // addLibrary with an explicit linkage.
        const mod = b.createModule(.{
            .root_source_file = b.path(m.root),
            .target = target,
            .optimize = m.optimize,
        });
        applyNative(b, mod, m.native);
        if (addBuildOptions(b, m.name, m.build_options)) |options| {
            mod.addOptions(m.build_options_import, options);
        }
        modules.put(m.name, mod) catch unreachable;
    }

    for (spec.modules) |m| {
        const mod = modules.get(m.name).?;
        for (m.pkg_imports) |pkg_import| {
            const dep = b.dependency(pkg_import.package, .{
                .target = target,
                .optimize = m.optimize,
            });
            mod.addImport(pkg_import.alias, dep.module(pkg_import.module));
        }
    }

    for (spec.modules) |m| {
        // Executables and shared libraries are always artifacts. A static
        // library is an artifact only when it is linked over the ABI; an
        // `import` static module compiles inside its dependents.
        const needs_artifact = switch (m.kind) {
            .exe, .shared => true,
            .static => m.link == .abi,
            .module => false,
        };
        if (!needs_artifact) continue;

        const mod = modules.get(m.name).?;
        const step = switch (m.kind) {
            .exe => b.addExecutable(.{
                .name = m.name,
                .root_module = mod,
            }),
            .static => b.addLibrary(.{
                .name = m.name,
                .root_module = mod,
                .linkage = .static,
            }),
            .shared => b.addLibrary(.{
                .name = m.name,
                .root_module = mod,
                .linkage = .dynamic,
            }),
            .module => unreachable,
        };
        for (m.pre, 0..) |cmd, idx| {
            const pre = addCommand(b, m.name, "pre", idx, cmd);
            step.step.dependOn(pre);
        }
        steps.put(m.name, step) catch unreachable;
    }

    for (spec.modules) |m| {
        const mod = modules.get(m.name).?;
        for (m.deps) |dep| {
            if (linkOf(dep) == .import and (kindOf(dep) == .static or kindOf(dep) == .module)) {
                // Merge the dependency into this compilation. Its source is
                // reached with `@import("<name>")`.
                mod.addImport(dep, modules.get(dep).?);
            } else {
                // 0.16 moved linkLibrary from Compile onto Module. Module.linkLibrary
                // exists in 0.14 and 0.15 too, so this spelling works on all three.
                mod.linkLibrary(steps.get(dep).?);
            }
        }
    }

    for (spec.modules) |m| {
        if (steps.get(m.name)) |step| {
            const install = b.addInstallArtifact(step, .{});
            for (m.post, 0..) |cmd, idx| {
                const post = addPostCommand(b, m.name, idx, cmd);
                post.dependencies.append(&install.step) catch unreachable;
                b.getInstallStep().dependOn(post);
            }
        }
    }

    // --- tests ---
    //
    // Three suites: the build-spec invariants that build.zig above relies on,
    // the small src/ helpers, and the vendored danzig core.
    const test_step = b.step("test", "Run all tests");

    const suites = [_][]const u8{
        "compat.zig",
        "build_spec_test.zig",
        "src/core_test.zig",
        "src/danzig/tests.zig",
    };

    for (suites) |suite| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(suite),
                .target = target,
                .optimize = .Debug,
            }),
        });
        const run_t = b.addRunArtifact(t);
        // build_spec_test reads module roots off disk, so run from the repo root.
        run_t.setCwd(b.path("."));
        test_step.dependOn(&run_t.step);
    }
}
