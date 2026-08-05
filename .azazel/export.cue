package build

_modules: {
	"xev":     xev
	"xev_lib": xev_lib
}

build: modules: {
	for k, v in _modules {
		(k): {
			kind:          v.kind
			root:          v.root
			deps:          v.deps
			optimize:      profiles[v.profile].optimize
			artifact_name: (v & {artifact_name: *k | string}).artifact_name
		}
	}
}
