# haskell-flake — Nix Flake Module for Haskell Development

`haskell-flake` is a [flake-parts](https://flake.parts/) module that provides a declarative, modular interface for building Haskell projects with Nix. It wraps the raw nixpkgs Haskell infrastructure (`pkgs.haskellPackages`, `callCabal2nix`, `shellFor`) behind a NixOS-module-style API: auto-detection of local packages from `cabal.project`, composable dependency overrides, per-package settings, devShell generation, and reusable project modules across repositories.

## When to use this skill

- Configuring `haskellProjects.<name>` in a flake-parts `flake.nix`
- Adding/overriding Haskell dependencies (from Hackage, Git repos, or local paths)
- Tuning per-package settings (`check`, `jailbreak`, `broken`, `cabalFlags`, `extraBuildDepends`, etc.)
- Setting up devShells with HLS, cabal-install, ghcid, and custom tools
- Sharing dependency overrides across repositories via `haskellFlakeProjectModules`
- Creating custom Haskell package sets (e.g., pinning a specific GHC version)
- Building Docker images from Haskell packages with Nix
- Optimizing closure size (`justStaticExecutables`, `removeReferencesTo`)
- Debugging haskell-flake evaluation with `--trace-verbose`
- Source filtering to avoid unnecessary rebuilds

---

## Overview

- [index.md](index.md) — Introduction: what haskell-flake is, relationship to flake-parts and nixpkgs.
- [under-the-hood.md](under-the-hood.md) — How haskell-flake wraps nixpkgs Haskell infrastructure; auto-detection of local packages, `cabal.project` parsing, modular interface.

## Getting Started

- [start.md](start.md) — Installation: `nix flake init -t github:srid/haskell-flake`, existing vs new project setup, `haskell-template`.
- [examples.md](examples.md) — Curated list of real-world projects using haskell-flake: `haskell-template`, `emanote`, `ema`, `hackage-server`, `nammayatri`, etc.

## Guide

- [local.md](local.md) — Local packages: single-package and multi-package (`cabal.project`) auto-detection, source filtering, avoiding rebuilds with `fileset.toSource`.
- [dependency.md](dependency.md) — Overriding dependencies: from Git repos (`flake.false` inputs), Hackage versions, multi-package monorepos, nixpkgs versions; sharing overrides via modules.
- [settings.md](settings.md) — Per-package settings: `check`, `haddock`, `jailbreak`, `broken`, `extraBuildDepends`, `librarySystemDepends`, `cabalFlags`, `patches`, `custom`, `drvAttrs`, `removeReferencesTo`, `generateOptparseApplicativeCompletions`, `buildFromSdist`, `stan`.
- [defaults.md](defaults.md) — Default options: `defaults.packages`, `defaults.devShell.tools`; overriding defaults.
- [devshell.md](devshell.md) — DevShell configuration: `mkShellArgs`, composing devShells via `outputs.devShell` and `inputsFrom`, integrating with `mission-control` / `flake-root`.
- [hls.md](hls.md) — IDE configuration: HLS included by default, disabling HLS, overriding `defaults.devShell.tools`.
- [package-set.md](package-set.md) — Creating custom Haskell package sets: `basePackages`, `outputs.finalPackages`, sharing via modules.
- [modules.md](modules.md) — Project modules: `flake.haskellFlakeProjectModules`, `haskellFlakeProjectModules.output`, sharing `packages`/`settings` across repos, module arguments (`pkgs`, `self`), non-default project export.
- [debugging.md](debugging.md) — Debug logging: `--trace-verbose` flag (Nix 2.10+), sample output, `traceVerbose`.
- [size.md](size.md) — Optimizing package size: `justStaticExecutables`, `removeReferencesTo`, `nix why-depends`, scanning docker images for bloat.
- [gotchas.md](gotchas.md) — Known issues: `libssh2` infinite recursion workaround.

## Reference

- [ref.md](ref.md) — Reference links: [module options](https://flake.parts/options/haskell-flake), Docker.
- [docker.md](docker.md) — Building Docker images: `dockerTools.buildImage`, `copyToRoot`, tagging with commit rev, SSL certs, size tips.
- [guide.md](guide.md) — Guide table of contents (navigation index).
