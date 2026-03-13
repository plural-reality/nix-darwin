# Base system configuration: programs, environment, macOS defaults
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}:
let
  gitPromptScript = ../scripts/git-prompt.sh;
in
{
  home.packages = with pkgs; [
    # Nix tooling
    nixfmt
    nil
    sops
    nixos-generators

    # AI tooling
    llm-agents.codex
    llm-agents.openclaw

    # Development
    tmux
    deno
    nodejs
    bun
    python3

    # Media processing
    ffmpeg
    imagemagick
    poppler

    # Utilities
    fdupes
    fzf
    yt-dlp
    glow
  ];

  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = userConfig.gitName;
          email = userConfig.gitEmail;
        };
        init.defaultBranch = "master";
        pull.rebase = true;
        filter.lfs = {
          process = "git-lfs filter-process";
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
        };
      };
      lfs.enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      autosuggestion.strategy = [
        "history"
        "completion"
        "match_prev_cmd"
      ];
      syntaxHighlighting.enable = true;
      autocd = true;
      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        lt = "tree";
        remake = "make -j clean && make -j";
      };
      initContent =
        let
          initExtraBeforeCompInit = lib.mkOrder 550 ''
            # Add completion to fpath
            fpath=(${config.home.homeDirectory}/.docker/completions $fpath)
          '';
          initExtra = lib.mkOrder 1000 ''
            # Source git prompt script
            source ${gitPromptScript}
            GIT_PS1_SHOWUPSTREAM="verbose"
            precmd () { __git_ps1 "%F{cyan}%~%f%F{blue}" "%s %f" }
          '';
        in
        lib.mkMerge [
          initExtraBeforeCompInit
          initExtra
        ];
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    gh = {
      enable = true;
    };
  };

  # VS Code: Nix-managed wrapper to prevent Cursor from hijacking `code`
  home.file.".local/bin/code" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$@"
    '';
  };

  # Environment variables
  home.sessionVariables = {
    MANPATH = ":/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/share/man";
    SHELL = "zsh";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # macOS defaults
  targets.darwin.defaults."com.apple.dock".autohide = true;
  targets.darwin.defaults."com.apple.dock".orientation = "bottom";
  targets.darwin.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  targets.darwin.defaults."com.apple.finder" = {
    FXPreferredViewStyle = "clmv";
    _FXShowPosixPathInTitle = true;
  };
}
