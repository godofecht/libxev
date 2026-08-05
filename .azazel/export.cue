package build

_modules: {
	"xev": xev
}

build: modules: {
	for k, v in _modules {
		(k): {
			kind:     v.kind
			root:     v.root
			deps:     v.deps
			optimize: profiles[v.profile].optimize
		}
	}
}
