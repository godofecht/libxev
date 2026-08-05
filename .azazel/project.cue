// Azazel parity model for libxev.
//
// First target slice: `lib:xev`, the static library. Mirrors libxev/build.zig's
// `addLibrary(.{ .linkage = .static, .name = "xev", .root_source_file =
// "src/c_api.zig" })`. libxev's library is self-contained pure Zig (c_api.zig
// imports main.zig relatively, no external package deps), so Azazel reproduces
// it directly. Verified: `zig build` on 0.16.0 produces zig-out/lib/libxev.a.
package build

toolchain: zig: {
	lanes: ["0.16"]
	preferred: "0.16"
}

xev: #Module & {
	kind: "static"
	root: "src/c_api.zig"
}
