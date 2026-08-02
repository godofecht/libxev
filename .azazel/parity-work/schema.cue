package build

#Kind:    "exe" | "static" | "shared" | "module"
#Profile: "debug" | "release"
#ZigLane: "0.14" | "0.15" | "0.16"
#OptionType: "bool" | "string" | "u32"

// How a module is consumed by the things that depend on it.
//
//   abi    a separately compiled artifact linked over the C ABI. Symbols cross
//          the edge as `pub export fn` / `extern fn`. Required for shared
//          libraries and for any C or C++ interop.
//   import merged into each dependent as a plain Zig module, reached with
//          `@import("<name>")`. One compilation, no link step. Much faster to
//          rebuild, and the only sensible choice for pure Zig-to-Zig edges.
//
// Default is `abi` so existing projects build unchanged.
#Link: "abi" | "import"

#Command: {
	argv: [...string]
}

#PackageImport: {
	alias:   string
	package: string
	module:  string
}

#Package: {
	url?: string
	hash?: string
	path?: string
	lazy: bool | *false
}

#Option: {
	name: string
	type: #OptionType
	description: string | *""
	default?: bool | string | int
}

#Native: {
	c_sources: [...string] | *[]
	include_dirs: [...string] | *[]
	system_include_dirs: [...string] | *[]
	library_paths: [...string] | *[]
	object_files: [...string] | *[]
	system_libs: [...string] | *[]
	pkg_config_libs: [...string] | *[]
	frameworks: [...string] | *[]
	link_libc: bool | *false
	link_libcpp: bool | *false
}

#Module: {
	kind:     #Kind
	root:     string
	deps: [...string] | *[]
	profile:  #Profile | *"debug"
	link:     #Link | *"abi"
	post: [...#Command] | *[]
	pre: [...#Command] | *[]
	pkg_imports: [...#PackageImport] | *[]
	build_options: [...string] | *[]
	build_options_import: string | *"build-options"
	native: #Native | *{}

	// A shared library is an ABI artifact by definition.
	if kind == "shared" {
		link: "abi"
	}

	// A module-only target has no artifact to link, so dependents consume it as
	// an import.
	if kind == "module" {
		link: "import"
	}
}

#Profiles: {
	debug: {
		optimize: "Debug"
	}
	release: {
		optimize: "ReleaseFast"
	}
}

#Toolchain: {
	zig: {
		// Azazel is maintained as explicit Zig API lanes. A project can narrow
		// this list when it relies on one lane's std.Build surface.
		lanes: [...#ZigLane] | *["0.14", "0.15", "0.16"]
		preferred: #ZigLane | *"0.15"
	}
}

profiles: #Profiles
toolchain: #Toolchain | *{}
packages: [string]: #Package | *{}
options: [...#Option] | *[]
