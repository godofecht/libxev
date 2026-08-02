package build

_modules: {
    "xev": xev
    "xev_probe": xev_probe
}

_toolchain: toolchain
_packages: packages
_options: options

build: modules: {
    for k, v in _modules {
        (k): {
            kind: v.kind
            root: v.root
            deps: v.deps
            link: v.link
            pre: v.pre
            post: v.post
            pkg_imports: v.pkg_imports
            build_options: v.build_options
            build_options_import: v.build_options_import
            native: v.native
            optimize: profiles[v.profile].optimize
        }
    }
}

build: toolchain: _toolchain
build: packages: _packages
build: options: _options
