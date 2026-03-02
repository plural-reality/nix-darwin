# Thin shell: imports shared modules, configures SOPS infrastructure
{
  config,
  pkgs,
  lib,
  userConfig,
  secretsFile,
  ...
}:
{
  imports = [
    ./modules/base.nix
    ./modules/claude-code.nix
    ./modules/shared-scripts.nix
  ];

  # ── SOPS infrastructure ────────────────────────────────────
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = secretsFile;
  };
  launchd.agents.sops-nix.config.EnvironmentVariables.PATH =
    lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";

  # ── Home Manager basics ────────────────────────────────────
  programs.home-manager.enable = true;

  home.username = userConfig.username;
  home.homeDirectory = "/Users/${userConfig.username}";
  home.stateVersion = "24.05";

  services.ollama.enable = true;
}
