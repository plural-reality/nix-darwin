# HM plumbing: user identity + SOPS infrastructure (conditional)
# Module selection is the downstream's responsibility via mkSystem { modules = [...]; }
{
  config,
  lib,
  userConfig,
  secretsFile,
  ...
}:
{
  # ── SOPS infrastructure (only when secretsFile is provided) ──
  sops = lib.mkIf (secretsFile != null) {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = secretsFile;
  };
  launchd.agents.sops-nix.config.EnvironmentVariables.PATH =
    lib.mkIf (secretsFile != null)
      (lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin");

  # ── Home Manager basics ────────────────────────────────────
  programs.home-manager.enable = true;

  home.username = userConfig.username;
  home.homeDirectory = "/Users/${userConfig.username}";
  home.stateVersion = "24.05";
}
