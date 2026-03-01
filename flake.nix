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
      # ==========================================
      # Reusable system builder (exported as lib.mkSystem)
      # ==========================================
      mkSystem =
        {
          userConfig,
          secretsFile,
          extraHomeModules ? [ ],
          extraDarwinModules ? [ ],
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
                # List packages installed in system profile.
                environment.systemPackages = [ pkgs.vim ];

                # Necessary for using flakes on this system.
                nix = {
                  settings = {
                    experimental-features = "nix-command flakes";
                    trusted-users = [
                      "root"
                      userConfig.username
                    ];
                    builders-use-substitutes = true;
                    accept-flake-config = true;
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

                # Set Git commit hash for darwin-version.
                system.configurationRevision = self.rev or self.dirtyRev or null;

                # Used for backwards compatibility
                system.stateVersion = 6;

                # The platform the configuration will be used on.
                nixpkgs.hostPlatform = system;

                ## Darwin Configurations
                # Allow unfree packages
                nixpkgs.config.allowUnfreePredicate =
                  pkg:
                  builtins.elem (lib.getName pkg) [
                    "claude-code"
                  ];

                # Define the user for home-manager
                users.users.${userConfig.username} = {
                  name = userConfig.username;
                  home = "/Users/${userConfig.username}";
                  shell = pkgs.zsh;
                };
                # Set primary user for homebrew and other user-specific options
                system.primaryUser = userConfig.username;
                # System defaults configuration
                system.defaults = {
                  CustomSystemPreferences."com.apple.security"."com.apple.security.authorization.ignoreArd" = true;
                };
                security.pam.services.sudo_local.touchIdAuth = true;

                # Homebrew configuration
                homebrew = {
                  enable = true;
                  casks = [
                    "blackhole-2ch"
                  ];
                };
              }
            )

            inputs.home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              # Explicitly inject userConfig and secretsFile into Home Manager modules
              home-manager.extraSpecialArgs = {
                inherit userConfig secretsFile;
              };
              home-manager.users.${userConfig.username} = {
                imports = [
                  ./home.nix
                  inputs.mac-app-util.homeManagerModules.default
                  inputs.sops-nix.homeManagerModules.sops
                ]
                ++ extraHomeModules;
              };
            }
          ]
          ++ extraDarwinModules;
        };

      # ==========================================
      # Author's configuration
      # ==========================================
      userConfig = {
        username = "yui";
        hostname = "Yuis-MacBook-Pro";
        gitName = "Yui Nishimura";
        gitEmail = "nisshi.yui79@gmail.com";
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

          # Team setup script: nix run github:yuidvg/nix-darwin#setup
          packages.setup = pkgs.writeShellApplication {
            name = "setup";
            runtimeInputs = with pkgs; [
              age
              sops
              git
            ];
            text = ''
              TEMPLATES=${./templates}
            ''
            + builtins.readFile ./setup.sh;
          };

          # Disposable test: nix run .#test-setup
          packages.test-setup = pkgs.writeShellApplication {
            name = "test-setup";
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
              | ${self'.packages.setup}/bin/setup

              echo ""
              echo "--- Validating ---"

              for f in flake.nix .sops.yaml secrets.yaml .gitignore apply; do
                [[ -f "$TARGET/$f" ]] && echo "OK: $f exists" || { echo "FAIL: $f missing"; exit 1; }
              done

              # Structure validation (no nix dependency needed)
              grep -q 'darwinConfigurations."Test-Mac"' "$TARGET/flake.nix"
              grep -q 'username = "testuser"' "$TARGET/flake.nix"
              grep -q 'gitEmail = "test@example.com"' "$TARGET/flake.nix"
              echo "OK: flake.nix contains expected substitutions"

              grep -q "sops" "$TARGET/secrets.yaml"
              echo "OK: secrets.yaml is sops-encrypted"

              grep -q "age1" "$TARGET/.sops.yaml"
              echo "OK: .sops.yaml contains age public key"

              [[ -x "$TARGET/apply" ]]
              echo "OK: apply is executable"

              git -C "$TARGET" log --oneline
              echo "OK: git repository initialized"

              echo ""
              echo "=== All tests passed ==="
            '';
          };
        };

      flake = {
        # Export mkSystem for downstream flakes
        lib = { inherit mkSystem; };

        # Author's darwin configuration
        darwinConfigurations."${userConfig.hostname}" = mkSystem {
          inherit userConfig;
          secretsFile = ./secrets.yaml;
          extraDarwinModules = [
            {
              nixpkgs.overlays = [
                inputs.rust-overlay.overlays.default
                (_final: _prev: {
                  screenpipe = import ./packages/screenpipe {
                    pkgs = _final;
                    screenpipe-src = inputs.screenpipe-src;
                  };
                })
              ];
            }
          ];
        };
      };
    };
}
