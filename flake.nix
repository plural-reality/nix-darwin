{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
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
                    extra-substituters = [ "https://cache.numtide.com" ];
                    extra-trusted-public-keys = [
                      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
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

                system.configurationRevision = self.rev or self.dirtyRev or null;
                system.stateVersion = 6;
                nixpkgs.hostPlatform = system;

                nixpkgs.overlays = [
                  inputs.llm-agents.overlays.default
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
                security.pam.services.sudo_local.touchIdAuth = true;

                homebrew = {
                  enable = true;
                };
              }
            )

            inputs.home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = {
                inherit userConfig secretsFile;
              };
              home-manager.users.${userConfig.username} =
                { config, lib, ... }:
                {
                  home.packages = [
                    inputs.kimi-cli.packages.${system}.default
                  ];

                  imports =
                    [
                      inputs.mac-app-util.homeManagerModules.default
                      ./modules/base.nix
                      ./modules/claude-code.nix
                      ./modules/shared-scripts.nix
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
                  launchd.agents.sops-nix.config.EnvironmentVariables.PATH =
                    lib.mkIf (secretsFile != null)
                      (lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin");
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

          # Screenpipe: standalone build via `nix build .#screenpipe`
          packages.screenpipe =
            let
              pkgsWithRust = pkgs.extend inputs.rust-overlay.overlays.default;
            in
            import ./packages/screenpipe {
              pkgs = pkgsWithRust;
              screenpipe-src = inputs.screenpipe-src;
            };

          # Formatter for the flake itself
          formatter = pkgs.nixfmt;

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

          # Apply: invoked via `nix run github:plural-reality/nix-darwin#apply`
          packages.apply = pkgs.writeShellApplication {
            name = "apply";
            text = ''
              nix flake update
              # Run all pending migrations from this upstream version
              ${self'.packages.migrate}/bin/migrate .
              if command -v darwin-rebuild &>/dev/null; then
                sudo darwin-rebuild switch --flake .
              else
                sudo nix run nix-darwin -- switch --flake .
              fi
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

              grep -q 'github:plural-reality/nix-darwin#apply' "$TARGET/apply"
              echo "OK: apply shim references upstream directly"

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
