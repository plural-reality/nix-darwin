---
date: "2026-03-26T09:11:17Z"
researcher: yui
git_commit: 9fd39e5faf7691746000217e6d7b0efa7c6bfea1
branch: main
repository: plural-reality/nix-darwin
topic: "onnxruntime 1.23.2 build failure dependency chain"
tags: [research, codebase, onnxruntime, markitdown, nix-darwin, build-failure]
status: complete
last_updated: "2026-03-26"
last_updated_by: yui
---

# Research: onnxruntime 1.23.2 build failure dependency chain

**Date**: 2026-03-26T09:11:17Z
**Researcher**: yui
**Git Commit**: 9fd39e5faf7691746000217e6d7b0efa7c6bfea1
**Branch**: main
**Repository**: plural-reality/nix-darwin

## Research Question
Trace the onnxruntime build failure and its cascading impact on the nix-darwin system build.

## Summary

`onnxruntime 1.23.2` fails to **compile** its test binary `onnxruntime_test_all` due to `-Werror` promoting `nodiscard` warnings in `graph_test.cc` to errors. The existing overlay at `flake.nix:110-116` sets `doCheck = false`, which skips **running** tests but does not prevent test code from being **compiled** as part of the default CMake `make all` target. This single compilation failure cascades through 5 Python packages and ultimately blocks the entire `darwin-system` build.

## Detailed Findings

### Root Cause: Compilation Error in Test Code

The build log shows 4 errors in `onnxruntime/test/ir/graph_test.cc` at lines 1247, 1316, 1345, and 1943:

```
error: ignoring return value of function declared with 'nodiscard' attribute [-Werror,-Wunused-result]
  model.ToProto().SerializeToString(&s1);
```

The onnxruntime CMake build includes test targets (`onnxruntime_test_all`, `onnxruntime_shared_lib_test`, `onnxruntime_perf_test`, etc.) in the default `all` target. With `-Werror` enabled, the `nodiscard` warnings in `graph_test.cc` become compilation errors.

### Existing Mitigation (Insufficient)

[`flake.nix:109-116`](https://github.com/plural-reality/nix-darwin/blob/9fd39e5faf7691746000217e6d7b0efa7c6bfea1/flake.nix#L109-L116):

```nix
# onnxruntime 1.23.2 test code fails with -Werror on macOS (nodiscard warning in graph_test.cc)
(final: prev: {
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyFinal: pyPrev: {
      onnxruntime = pyPrev.onnxruntime.overrideAttrs (_: { doCheck = false; });
    })
  ];
})
```

`doCheck = false` disables the Nix **check phase** (which would run the test executables). However, the onnxruntime CMake configuration builds test binaries during the **build phase** itself, so the compilation error occurs before `doCheck` is relevant.

### Dependency Chain

```
onnxruntime 1.23.2 (C++ build fails)
├── python3.13-onnxruntime 1.23.2 (direct dependency)
│   ├── python3.13-faster-whisper 1.2.1 (transitive)
│   ├── python3.13-magika 1.0.2 (transitive)
│   └── python3.13-markitdown 0.1.4 (transitive)
│       ├── markthesedown (shared-scripts.nix:68-71)
│       ├── python3.13-markitdown-0.1.4-fish-completions
│       └── markthesedownPythonEnv (shared-scripts.nix:5-17)
├── home-manager-applications
├── home-manager-fonts
├── home-manager-path
├── man-paths
├── home-manager-generation
├── user-environment
├── activation-yui
└── darwin-system-26.05 (entire system blocked)
```

### Where Packages Are Declared

**Direct declarations in this repo:**

| Package | File | Line | How |
|---------|------|------|-----|
| onnxruntime overlay | `flake.nix` | 110-116 | `pythonPackagesExtensions` overlay |
| markitdown (binary) | `modules/shared-scripts.nix` | 254 | `pkgs.python313Packages.markitdown` in `home.packages` |
| markitdown (Python env) | `modules/shared-scripts.nix` | 6 | `ps.markitdown` in `markthesedownPythonEnv` |
| markthesedown (wrapper) | `modules/shared-scripts.nix` | 68-71 | `writeScriptBin` calling markitdown via tar-map |

**Not declared in this repo (transitive from nixpkgs):**

- `faster-whisper` — pulled in as a dependency of `markitdown`
- `magika` — pulled in as a dependency of `markitdown`

### Build Error Details

The failing derivation: `/nix/store/7zx5l8kcbfgqphwz2pfq87qky7aw6cgi-onnxruntime-1.23.2.drv`

The specific CMake target that fails: `onnxruntime_test_all` (at 75% of the build).

Other test targets (`onnxruntime_shared_lib_test`, `onnxruntime_perf_test`, `onnxruntime_ep_graph_test`, etc.) compile and link successfully. Only `onnxruntime_test_all` fails because it includes `graph_test.cc`.

The `onnxruntime_pybind11_state` shared library (the actual runtime artifact) builds successfully at 78%, but `make all` still fails because `onnxruntime_test_all` is part of the default target.

## Code References

- `flake.nix:107-117` — nixpkgs overlays (llm-agents + onnxruntime doCheck override)
- `modules/shared-scripts.nix:5-17` — markthesedownPythonEnv (includes markitdown)
- `modules/shared-scripts.nix:68-71` — markthesedown wrapper script
- `modules/shared-scripts.nix:254` — explicit markitdown package in home.packages

## Architecture Documentation

The overlay strategy uses `pythonPackagesExtensions` to apply the onnxruntime override globally across all Python package sets. This correctly targets both the standalone `onnxruntime` and any Python environment that includes it (like `markthesedownPythonEnv`). The issue is that `doCheck = false` is the wrong lever for this particular failure — the test code is compiled during the build phase, not just executed during the check phase.

## Open Questions

1. What CMake flags does the nixpkgs onnxruntime derivation pass? Specifically, is there a flag like `onnxruntime_BUILD_UNIT_TESTS` that controls whether test targets are included in `make all`?
2. Is this a known regression in nixpkgs-unstable for onnxruntime 1.23.2 on macOS?
