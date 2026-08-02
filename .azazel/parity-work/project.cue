package build

toolchain: zig: {
    lanes: ["0.16"]
    preferred: "0.16"
}

xev: #Module & {
    kind: "module"
    root: "../../src/main.zig"
}

xev_probe: #Module & {
    kind: "exe"
    root: "src/xev_probe.zig"
    deps: ["xev"]
    link: "import"
}
