// Full Azazel parity model for libxev, using artifact_name (azazel #36).
//
// libxev exposes both an importable Zig module named xev (src/main.zig, used via
// @import("xev")) and a C-API static library also named xev (src/c_api.zig,
// producing libxev.a). Before #36 a #Module's key was both its @import name and
// its artifact name, so these two "xev" targets could not coexist. artifact_name
// decouples them: the module keeps the "xev" key, and the static library uses a
// distinct key while emitting the real libxev.a. Both primary targets modeled.
package build

toolchain: zig: {
	lanes: ["0.16"]
	preferred: "0.16"
}

xev: #Module & {
	kind: "module"
	root: "src/main.zig"
}

xev_lib: #Module & {
	kind:          "static"
	root:          "src/c_api.zig"
	artifact_name: "xev"
}
