# Haskell Language Server (HLS) — IDE Features for Haskell via LSP

The Haskell Language Server (HLS) is an implementation of the Language Server Protocol (LSP) for Haskell. It provides IDE-like features — diagnostics, completions, hover info, code actions, formatting, and more — to any editor that supports LSP (VS Code, Neovim, Emacs, Vim, Helix, Kakoune, etc.). HLS uses a plugin architecture where individual features are provided by composable, independently-configurable plugins. Under the hood, `hie-bios` resolves project build configuration (via cabal or stack cradles), and `haskell-language-server-wrapper` selects the correct GHC-matched binary automatically.

## When to use this skill

- Setting up or troubleshooting HLS in a Haskell project
- Configuring HLS plugins, formatters (ormolu, fourmolu, stylish-haskell), or editor integration
- Understanding what IDE features HLS provides (code actions, lenses, diagnostics, refactoring)
- Writing or debugging `hie.yaml` cradle configuration for multi-component projects
- Diagnosing build failures, wrong GHC version errors, or missing tool issues in HLS
- Installing HLS via ghcup, Nix, Homebrew, or from source

---

## Additional Resources

### Overview & Architecture
- [What is HLS](what-is-hls.md) — LSP concepts, server/client architecture, the HLS wrapper, plugin system, and hie-bios cradle mechanism

### Setup
- [Installation](installation.md) — Installation methods: ghcup, Nix, Homebrew, VS Code auto-install, pre-built binaries, source builds, and platform-specific packages (Arch, Fedora, FreeBSD, Gentoo)

### Configuration
- [Configuration](configuration.md) — Server settings (formatter, completions, check modes), plugin-level configuration, `hie.yaml` cradle setup (cabal, stack, bios, multi-component), Haddock on hover, and editor-specific setup (VS Code, Neovim, Vim/Coc, Emacs/eglot/lsp-mode, Sublime, Kakoune, Helix)

### Capabilities
- [Features](features.md) — Full feature reference: diagnostics (GHC, hlint, stan, cabal), hover, signature help, jump to definition/type/implementation, find references, completions, formatting, document/workspace symbols, call hierarchy, code actions (pragmas, hlint fixes, explicit imports, class methods, retrie, splice, GADT conversion, record fields, cabal dependencies), code lenses (type signatures, eval, module names), selection/folding range, rename, semantic tokens

### Debugging
- [Troubleshooting](troubleshooting.md) — Diagnosis workflow (server logs, command-line reproduction, plugin isolation), common issues (wrong GHC binary, unsupported versions, missing tools, cradle misconfiguration, multi-cradle errors, static binary linker issues, preprocessors, multi-component stack limitations)
