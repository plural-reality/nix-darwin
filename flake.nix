{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:numtide/nixpkgs-unfree?ref=nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    mac-app-util.url = "github:hraban/mac-app-util";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Rust nightly toolchain (required by screenpipe's edition2024 dependency)
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Screenpipe: raw source (no flake.nix upstream)
    screenpipe-src.url = "github:screenpipe/screenpipe/v0.3.135";
    screenpipe-src.flake = false;

    # Kimi Code CLI agent
    kimi-cli.url = "github:MoonshotAI/kimi-cli";

    # AI coding agents: Claude Code, Codex, etc. (daily auto-updated overlay)
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Haskell Dev Environment
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      flake-parts,
      haskell-flake,
      ...
    }:
    let
      mkSystem =
        {
          userConfig,
          secretsFile ? null,
          modules ? [ ],
          system ? "aarch64-darwin",
          upstreamPath ? null,
          enableHomeManager ? true,
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit userConfig;
          };

          modules = [
            (
              {
                pkgs,
                lib,
                userConfig,
                ...
              }:
              {
                nix = {
                  settings = {
                    experimental-features = "nix-command flakes";
                    trusted-users = [
                      "root"
                      userConfig.username
                    ];
                    builders-use-substitutes = true;
                    accept-flake-config = true;
                    # A system generation must be reproducible from committed sources.
                    # Development remains possible in a separate worktree, but a dirty
                    # tree is never a valid Nix input for build or activation.
                    allow-dirty = false;
                    allow-dirty-locks = false;
                    extra-substituters = [
                      "https://cache.numtide.com"
                      "https://plural-reality.cachix.org"
                      "https://devenv.cachix.org"
                    ];
                    extra-trusted-public-keys = [
                      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
                      "plural-reality.cachix.org-1:239F7m1UlqIqB/08o1JTXsUbICmBZgRV/65dtiDrzR8="
                      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
                    ];
                  };
                  linux-builder = {
                    enable = true;
                    ephemeral = true;
                    maxJobs = 4;
                    config = {
                      virtualisation = {
                        darwin-builder = {
                          diskSize = 40 * 1024;
                          memorySize = 8 * 1024;
                        };
                        cores = 6;
                      };
                    };
                  };
                };

                assertions = [
                  {
                    assertion = self ? rev;
                    message = "nix-darwin upstream must be a committed Git revision, not a dirty source tree";
                  }
                ];

                system.configurationRevision = self.rev;
                system.stateVersion = 6;
                nixpkgs.hostPlatform = system;

                nixpkgs.overlays = [
                  inputs.llm-agents.overlays.shared-nixpkgs
                  # onnxruntime 1.23.2 test code fails with -Werror on macOS (nodiscard warning in graph_test.cc)
                  (final: prev: {
                    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                      (pyFinal: pyPrev: {
                        onnxruntime = pyPrev.onnxruntime.overrideAttrs (_: {
                          doCheck = false;
                        });
                        # pydub only needs ffmpeg/ffplay/ffprobe. Avoid ffmpeg-full's
                        # kvazaar check path on Darwin while preserving pydub behavior.
                        pydub = pyPrev.pydub.override { ffmpeg-full = final.ffmpeg; };
                        # speechrecognition's test closure builds optional whisper backends;
                        # openai-whisper's audio test fails under the Darwin sandbox.
                        speechrecognition = pyPrev.speechrecognition.overridePythonAttrs (_: {
                          doCheck = false;
                        });
                      })
                    ];
                  })
                ];
                nixpkgs.config.allowUnfreePredicate =
                  pkg:
                  builtins.elem (lib.getName pkg) [
                    "claude"
                    "claude-code"
                  ];

                users.users.${userConfig.username} = {
                  name = userConfig.username;
                  home = "/Users/${userConfig.username}";
                  shell = pkgs.zsh;
                };
                system.primaryUser = userConfig.username;
                system.defaults = {
                  CustomSystemPreferences."com.apple.security"."com.apple.security.authorization.ignoreArd" = true;
                };
                security.pam.services.sudo_local = {
                  touchIdAuth = true;
                  reattach = true; # tmux/screen の中でも TouchID を効かせる (pam_reattach)。これが無いと tmux 内 sudo はパスワードに落ちる
                };

                homebrew = {
                  enable = true;
                };
              }
            )

            ./modules/codex-hooks.nix

          ]
          ++ nixpkgs.lib.optionals enableHomeManager [
            inputs.home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit userConfig secretsFile upstreamPath;
              };
              home-manager.users.${userConfig.username} =
                {
                  config,
                  lib,
                  pkgs,
                  ...
                }:
                {
                  home.packages = [
                    inputs.kimi-cli.packages.${system}.default
                    (import ./packages/codelayer { inherit pkgs; })
                  ];

                  imports = [
                    inputs.mac-app-util.homeManagerModules.default
                    ./modules/base.nix
                    ./modules/claude-code.nix
                    ./modules/shared-scripts.nix
                    ./modules/claude-agent-scripts.nix
                  ]
                  ++ (nixpkgs.lib.optional (secretsFile != null) inputs.sops-nix.homeManagerModules.sops);

                  programs.home-manager.enable = true;
                  home.username = userConfig.username;
                  home.homeDirectory = "/Users/${userConfig.username}";
                  home.stateVersion = "24.05";

                  sops = lib.mkIf (secretsFile != null) {
                    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
                    defaultSopsFile = secretsFile;
                  };
                  launchd.agents.sops-nix.config.EnvironmentVariables.PATH = lib.mkIf (secretsFile != null) (
                    lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin"
                  );
                };
            }
          ]
          ++ modules;
        };

      # Complete downstream flake outputs: darwinConfigurations + devShells + formatter + apps
      mkDownstreamFlake =
        {
          userConfig,
          secretsFile ? null,
          modules ? [ ],
          system ? "aarch64-darwin",
          upstreamPath ? null,
          enableHomeManager ? true,
        }:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          darwinConfigurations.${userConfig.hostname} = mkSystem {
            inherit
              userConfig
              secretsFile
              modules
              system
              upstreamPath
              enableHomeManager
              ;
          };
          devShells.${system}.default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              nil
            ];
          };
          formatter.${system} = pkgs.nixfmt;
          apps.${system}.apply = {
            type = "app";
            program = "${self.packages.${system}.apply}/bin/apply";
          };
        };

    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem =
        {
          self',
          pkgs,
          config,
          ...
        }:
        {
          # Haskell Configuration via haskell-flake
          haskellProjects.default = {
            # The scripts directory containing the .cabal file
            projectRoot = ./scripts;

            devShell = {
              enable = true;
              tools = hp: {
                haskell-language-server = hp.haskell-language-server;
                fourmolu = hp.fourmolu;
                cabal-gild = pkgs.haskellPackages.cabal-gild;
              };
              hlsCheck.enable = true;
              hoogle = false;
            };
          };

          # XcodeBuildMCP: hermetic MCP server (no npx)
          packages.xcodebuildmcp = import ./packages/xcodebuildmcp { inherit pkgs; };

          # freee MCP: published ESM plus runtime npm closure, fully Nix-pinned.
          packages.freee-mcp = import ./packages/freee-mcp { inherit pkgs; };

          # Official Plaud CLI, pinned for personal lifelog adapters.
          packages.plaud-cli = import ./packages/plaud-cli { inherit pkgs; };

          # CodeLayer: AI coding agent (macOS .app + CLI)
          packages.codelayer = import ./packages/codelayer { inherit pkgs; };

          # Screenpipe: standalone build via `nix build .#screenpipe`
          packages.screenpipe =
            let
              pkgsWithRust = pkgs.extend inputs.rust-overlay.overlays.default;
            in
            import ./packages/screenpipe {
              pkgs = pkgsWithRust;
              screenpipe-src = inputs.screenpipe-src;
            };

          # Claude Code skills → Claude Desktop uploadable ZIPs
          packages.desktop-skills = import ./packages/desktop-skills {
            inherit pkgs;
            skillsDir = ./prompt/claude-code/skills;
          };

          # Copy skill ZIPs to ~/Desktop (or custom dir)
          # Usage: nix run .#zip-skills [-- /path/to/output]
          packages.zip-skills = pkgs.writeShellApplication {
            name = "zip-skills";
            text = ''
              OUTDIR="''${1:-$HOME/Desktop}/claude-skills"
              mkdir -p "$OUTDIR"

              echo "Copying skill ZIPs to $OUTDIR ..."

              copied=()
              for zip in "${self'.packages.desktop-skills}"/*.zip; do
                name=$(basename "$zip")
                cp -f "$zip" "$OUTDIR/$name"
                copied+=("$name")
                echo "  $name"
              done

              echo ""
              echo "=== ''${#copied[@]} skill ZIPs exported to $OUTDIR ==="
            '';
          };

          apps.zip-skills = {
            type = "app";
            program = "${self'.packages.zip-skills}/bin/zip-skills";
          };

          # Formatter for the flake itself
          formatter = pkgs.nixfmt;

          checks.evkit-snapshot =
            pkgs.runCommand "evkit-snapshot-check"
              {
                nativeBuildInputs = [
                  pkgs.clang
                  pkgs.swift
                ];
              }
              ''
                export MACOSX_DEPLOYMENT_TARGET=14.0
                swiftc -parse-as-library -O ${./scripts/claude/evkit/evkitd.swift} -o evkitd
                swiftc -parse-as-library -D EVKIT_TESTING \
                  ${./scripts/claude/evkit/evkitd.swift} \
                  ${./scripts/claude/evkit/evkitd.test.swift} \
                  -o evkitd-tests
                ./evkitd-tests
                touch "$out"
              '';

          # Pure core check for the signed Message History bridge. Signing and
          # Full Disk Access remain explicit activation-time boundaries.
          checks.message-history-bridge =
            pkgs.runCommand "message-history-bridge-check"
              {
                nativeBuildInputs = [
                  pkgs.clang
                  pkgs.swift
                ];
                buildInputs = [ pkgs.sqlite ];
              }
              ''
                mkdir sqlite-module
                cat > sqlite-module/module.modulemap <<'MODULEMAP'
                module CSQLite [system] {
                  header "${pkgs.sqlite.dev}/include/sqlite3.h"
                  link "sqlite3"
                  export *
                }
                MODULEMAP
                swiftc -D IMSG_HISTORY_TESTING -parse-as-library -Onone \
                  ${./scripts/claude/imsg-history/message-historyd.swift} \
                  ${./scripts/claude/imsg-history/message-historyd.test.swift} \
                  -I sqlite-module \
                  -lsqlite3 -o message-historyd-tests
                ./message-historyd-tests
                touch "$out"
              '';

          # Pure protocol/selection check for the signed Photos bridge. Signing,
          # PhotoKit authorization, and asset export stay activation-time effects.
          checks.photo-library-bridge =
            pkgs.runCommand "photo-library-bridge-check"
              {
                nativeBuildInputs = [
                  pkgs.clang
                  pkgs.swift
                ];
              }
              ''
                export MACOSX_DEPLOYMENT_TARGET=14.0
                swiftc -D PHOTO_LIBRARY_TESTING -swift-version 5 -parse-as-library -Onone \
                  ${./scripts/claude/photo-library/photo-libraryd.swift} \
                  ${./scripts/claude/photo-library/photo-libraryd.test.swift} \
                  -framework AppKit -framework Photos -framework Vision -framework CryptoKit \
                  -o photo-libraryd-tests
                ./photo-libraryd-tests
                touch "$out"
              '';

          checks.freee-mcp-offline =
            pkgs.runCommand "freee-mcp-offline-check"
              {
                nativeBuildInputs = [
                  pkgs.gnugrep
                  self'.packages.freee-mcp
                ];
              }
              ''
                export HOME="$TMPDIR/home"
                export FREEE_CLIENT_ID="offline-check"
                export FREEE_CLIENT_SECRET="offline-check"
                mkdir -p "$HOME"
                freee-mcp </dev/null >stdout 2>stderr || {
                  cat stderr >&2
                  exit 1
                }
                test ! -s stdout
                grep -F '"version":"0.26.7"' stderr >/dev/null
                touch "$out"
              '';

          # Keep the deployment boundary fail-closed. This is intentionally a
          # small contract check rather than a system activation test.
          checks.immutable-apply-contract =
            pkgs.runCommand "immutable-apply-contract-check"
              {
                nativeBuildInputs = [
                  pkgs.gnugrep
                  self'.packages.apply
                ];
              }
              ''
                script="${self'.packages.apply}/bin/apply"
                grep -F -- 'GIT_OPTIONAL_LOCKS=0 git' "$script" >/dev/null
                grep -F -- 'status --porcelain=v1 --untracked-files=all' "$script" >/dev/null
                grep -F -- '--no-write-lock-file' "$script" >/dev/null
                grep -F -- '--option allow-dirty false' "$script" >/dev/null
                ! grep -F -- 'nix flake update nix-darwin-upstream' "$script"
                ! grep -F -- '/bin/migrate' "$script"
                touch "$out"
              '';

          checks.codex-task-audit =
            pkgs.runCommand "codex-task-audit-check"
              {
                nativeBuildInputs = [ pkgs.nodejs_22 ];
              }
              ''
                cp ${./scripts/codex-task-audit.ts} codex-task-audit.ts
                cp ${./scripts/codex-task-audit.test.ts} codex-task-audit.test.ts
                node --disable-warning=ExperimentalWarning --experimental-strip-types --experimental-sqlite \
                  --test codex-task-audit.test.ts
                touch "$out"
              '';

          # Migration: nix run github:plural-reality/nix-darwin#migrate
          packages.migrate = pkgs.writeShellApplication {
            name = "migrate";
            runtimeInputs = with pkgs; [ nixfmt ];
            text = ''
              MIGRATIONS=${./downstream/migrations}
            ''
            + builtins.readFile ./downstream/migrate.sh;
          };

          # Team setup script: nix run github:plural-reality/nix-darwin#setup-downstream
          packages.setup-downstream = pkgs.writeShellApplication {
            name = "setup-downstream";
            runtimeInputs = with pkgs; [
              age
              sops
              git
            ];
            text = ''
              TEMPLATES=${./downstream/templates}
            ''
            + builtins.readFile ./downstream/setup.sh;
          };

          # Apply: invoked from a downstream flake via `nix run .#apply`.
          # It consumes the already-locked source graph and never updates a lock
          # file or mutates the downstream checkout.
          packages.apply = pkgs.writeShellApplication {
            name = "apply";
            runtimeInputs = with pkgs; [
              coreutils
              git
              nix
            ];
            text = ''
              flake_dir="''${NIX_DARWIN_FLAKE:-$PWD}"
              test -z "$(GIT_OPTIONAL_LOCKS=0 git -C "$flake_dir" status --porcelain=v1 --untracked-files=all)" || {
                printf '%s\n' "refusing deployment: downstream worktree is dirty: $flake_dir" >&2
                exit 1
              }
              host="$(scutil --get LocalHostName)"
              system_path="$(nix build \
                --no-write-lock-file \
                --option allow-dirty false \
                --option allow-dirty-locks false \
                "$flake_dir#darwinConfigurations.\"$host\".system" \
                --no-link --print-out-paths)"
              if darwin_rebuild="$(command -v darwin-rebuild)"; then
                sudo "$darwin_rebuild" switch \
                  --flake "$flake_dir" \
                  --no-write-lock-file \
                  --option allow-dirty false \
                  --option allow-dirty-locks false
              else
                sudo /nix/var/nix/profiles/default/bin/nix run nix-darwin -- switch \
                  --flake "$flake_dir" \
                  --no-write-lock-file \
                  --option allow-dirty false \
                  --option allow-dirty-locks false
              fi
              test "$(realpath /run/current-system)" = "$system_path" || {
                printf '%s\n' "activation mismatch: expected $system_path, got $(realpath /run/current-system)" >&2
                exit 1
              }
            '';
          };

          # Disposable test: nix run .#test-setup
          packages.test-setup-downstream = pkgs.writeShellApplication {
            name = "test-setup-downstream";
            runtimeInputs = with pkgs; [ git ];
            text = ''
              WORKDIR=$(mktemp -d)
              trap 'rm -rf "$WORKDIR"' EXIT

              export HOME="$WORKDIR/home"
              mkdir -p "$HOME"

              TARGET="$WORKDIR/nix-darwin"
              mkdir -p "$TARGET"

              printf '%s\n' \
                "testuser" \
                "Test-Mac" \
                "Test User" \
                "test@example.com" \
                "$TARGET" \
                "" \
                "" \
                "" \
              | ${self'.packages.setup-downstream}/bin/setup-downstream

              echo ""
              echo "--- Validating ---"

              for f in flake.nix .sops.yaml secrets.yaml .gitignore apply .envrc; do
                if [[ -f "$TARGET/$f" ]]; then
                  echo "OK: $f exists"
                else
                  echo "FAIL: $f missing"
                  exit 1
                fi
              done

              # Structure validation (no nix dependency needed)
              grep -q 'mkDownstreamFlake' "$TARGET/flake.nix"
              grep -q 'username = "testuser"' "$TARGET/flake.nix"
              grep -q 'hostname = "Test-Mac"' "$TARGET/flake.nix"
              grep -q 'gitEmail = "test@example.com"' "$TARGET/flake.nix"
              echo "OK: flake.nix contains expected substitutions"

              grep -q "sops" "$TARGET/secrets.yaml"
              echo "OK: secrets.yaml is sops-encrypted"

              grep -q "age1" "$TARGET/.sops.yaml"
              echo "OK: .sops.yaml contains age public key"

              [[ -x "$TARGET/apply" ]]
              echo "OK: apply is executable"

              grep -q 'nix run .#apply' "$TARGET/apply"
              echo "OK: apply shim delegates to the downstream flake"

              git -C "$TARGET" log --oneline
              echo "OK: git repository initialized"

              echo ""
              echo "=== All tests passed ==="
            '';
          };
        };

      flake = {
        lib = { inherit mkSystem mkDownstreamFlake; };
      };
    };
}
