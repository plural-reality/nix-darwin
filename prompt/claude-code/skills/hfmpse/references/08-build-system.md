# 8. Build System (haskell-flake + flake-parts)

### flake.nix

```nix
{
  description = "HFMPSE full-stack application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
    project-m36-src = {
      url = "github:agentm/project-m36/<commit>";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem = { self', pkgs, lib, system, ... }: {

        # ── Haskell ──────────────────────────────────────
        haskellProjects.default = {
          projectRoot = ./backend;
          settings = {
            project-m36-base.source = inputs.project-m36-src;
            # project-m36-base.jailbreak = true;  # if needed
          };
          devShell = {
            tools = hp: {
              inherit (hp) cabal-install haskell-language-server fourmolu;
            };
            mkShellArgs.buildInputs = with pkgs; [
              elmPackages.elm elmPackages.elm-format elmPackages.elm-test
              just
            ];
          };
        };

        # ── Elm ──────────────────────────────────────────
        packages.frontend = pkgs.stdenv.mkDerivation {
          pname = "myapp-frontend";
          version = "0.1.0";
          src = ./frontend;
          nativeBuildInputs = [ pkgs.elmPackages.elm ];
          buildPhase = ''
            export HOME=$TMPDIR
            elm make src/Main.elm --optimize --output=main.js
          '';
          installPhase = ''
            mkdir -p $out
            cp main.js $out/
            cp index.html $out/ 2>/dev/null || true
          '';
        };

        # ── servant-elm codegen ──────────────────────────
        # Exposed as: nix run .#codegen
        apps.codegen = {
          type = "app";
          program = "${self'.packages.default}/bin/myapp-codegen";
        };

        # ── Combined package (build output contract) ─────
        # Contains: bin/myapp-server + static/
        packages.myapp = pkgs.symlinkJoin {
          name = "myapp";
          paths = [ self'.packages.default ];
          postBuild = ''
            mkdir -p $out/static
            cp ${self'.packages.frontend}/* $out/static/
          '';
        };

        # ── CI: codegen consistency ──────────────────────
        checks.codegen-consistent = pkgs.runCommand "codegen-check" {
          nativeBuildInputs = [ self'.packages.default pkgs.diffutils ];
        } ''
          cp -r ${./frontend/src/Api} $TMPDIR/before
          myapp-codegen --output-dir $TMPDIR/generated
          diff -r $TMPDIR/before $TMPDIR/generated/Api || {
            echo "ERROR: Generated.elm is out of date. Run: nix run .#codegen"
            exit 1
          }
          touch $out
        '';
      };
    };
}
```

### cabal Structure

The `.cabal` file must define three targets sharing a common library:

```cabal
cabal-version: 3.0
name:          myapp
version:       0.1.0

-- Shared types: Api, Domain, Effects (imported by both server and codegen)
library
  exposed-modules:
    MyApp.Api
    MyApp.Api.Types
    MyApp.Domain.Types
    MyApp.Domain.Events
    -- all modules needed by both server and codegen
  build-depends:
    , base, servant, polysemy, project-m36-base
    , aeson, text, uuid, time, servant-elm
  default-language: GHC2021

-- Warp server (the deployable binary)
executable myapp-server
  main-is:       Main.hs
  hs-source-dirs: app
  build-depends:  base, myapp, servant-server, warp, polysemy
  default-language: GHC2021

-- servant-elm code generator
executable myapp-codegen
  main-is:       Main.hs
  hs-source-dirs: codegen
  build-depends:  base, myapp, servant-elm, servant
  default-language: GHC2021
```

The **library** is the critical piece — it contains the Servant API type and all request/response types. Both `myapp-server` and `myapp-codegen` depend on it, guaranteeing they reference the same types.

### haskell-flake with Project:M36

If M36 is not on Hackage or needs a pinned version, add it as a non-flake input and reference it in `settings`:

```nix
# In flake inputs:
project-m36-src = { url = "github:agentm/project-m36/<commit>"; flake = false; };

# In haskellProjects.default.settings:
project-m36-base.source = inputs.project-m36-src;
```

### devShell

haskell-flake auto-generates a devShell with GHC, cabal, and HLS. The `mkShellArgs.buildInputs` extension adds Elm tools. `nix develop` gives you everything needed for both Haskell and Elm development.

### Build Commands (justfile)

```just
dev:       nix develop
build:     nix build .#myapp
codegen:   nix run .#codegen && cd frontend && elm make src/Main.elm --output=/dev/null
test:      cd backend && cabal test && cd ../frontend && elm-test
check:     nix flake check
run:       cd backend && cabal run myapp-server
```

