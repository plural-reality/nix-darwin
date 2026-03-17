---
date: 2026-03-17T00:00:00+09:00
researcher: Claude
git_commit: b3579c8dfffe190e32075a879dbd7522c1141ae9
branch: main
repository: plural-reality/nix-darwin
topic: "How does this nix-darwin repo structure scripts and add them to PATH?"
tags: [research, codebase, nix-darwin, scripts, PATH]
status: complete
last_updated: 2026-03-17
last_updated_by: Claude
---

# Research: nix-darwin Script Packaging & PATH Patterns

**Git Commit**: b3579c8
**Branch**: main

## Summary

This repo is an **upstream shared nix-darwin library flake**. It exports `mkSystem`/`mkDownstreamFlake` that downstream personal repos consume. Scripts are packaged as Nix derivations and added to `home.packages` across three modules: `base.nix`, `shared-scripts.nix`, `claude-code.nix`.

## Script Packaging Patterns

### Pattern A: `writeScriptBin` + absolute store-path shebang (primary pattern for Python/Bash)

```nix
# modules/shared-scripts.nix:158
urls-under = pkgs.writeScriptBin "urls-under" ''
  #!${webScrapingPythonEnv}/bin/python
  ${builtins.readFile ../scripts/urls-under.py}
'';
```

- Shebang points to Nix store Python
- Source read from separate file via `builtins.readFile`
- For stdlib-only Python: `#!${pkgs.python313}/bin/python` (see `cat-all`, `flatten-dir`)
- For Python with deps: define `pkgs.python313.withPackages (...)` env first

### Pattern B: `writeShellApplication` (for shell scripts needing runtime deps)

```nix
# modules/shared-scripts.nix:200
ch = pkgs.writeShellApplication {
  name = "ch";
  runtimeInputs = with pkgs; [ fzf jq coreutils gnused ];
  text = builtins.readFile ../scripts/claude-history.sh;
};
```

### Pattern C: `writers.writeHaskellBin` (compiled Haskell)

```nix
# modules/shared-scripts.nix:29
tar-map = pkgs.writers.writeHaskellBin "tar-map" {
  libraries = with pkgs.haskellPackages; [ ... ];
} (builtins.readFile ../scripts/tar-map.hs);
```

## How Scripts Reach PATH

All script derivations are appended to `home.packages` in their respective module:

| Module | Location | What |
|--------|----------|------|
| `flake.nix:145` | Inline HM block | `kimi-cli`, `codelayer` |
| `modules/base.nix:13` | Shared base | `nixfmt`, `codex`, `tmux`, `deno`, `python3`, etc. |
| `modules/shared-scripts.nix:224` | Stream tools | `tar-map`, `urls-under`, `save-site`, `ch`, etc. |
| `modules/claude-code.nix:137` | AI agents | `claude-code` |

Home Manager merges all `home.packages` lists and links them into `~/.nix-profile/bin/`.

Additionally, `home.sessionPath = ["~/.local/bin"]` (`base.nix:245`) adds a path for `home.file`-based executable shims.

## File Locations

- `flake.nix` — inputs, `mkSystem`, `mkDownstreamFlake`, `perSystem` packages
- `modules/base.nix` — shared dev env (git, zsh, neovim, packages)
- `modules/shared-scripts.nix` — script derivations + `home.packages`
- `modules/claude-code.nix` — AI agent config + `home.packages`
- `prompt/claude-code/skills/prompt-review/scripts/collect.py` — target script to package
