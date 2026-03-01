{
  config,
  pkgs,
  lib,
  mac-app-util,
  userConfig,
  secretsFile,
  ...
}:
let
  # 1. 必要なライブラリを含んだPython環境を定義
  #    ※ python313Packages があるなら明示的に python313 を使うのが安全です
  markthesedownPythonEnv = pkgs.python313.withPackages (ps: [
    ps.markitdown
    ps.openai
    ps.openpyxl
    ps.python-pptx
    ps.youtube-transcript-api
    ps.speechrecognition
    ps.pydub
    ps.requests
    ps.pandas
    ps.beautifulsoup4
    ps.joblib
  ]);

  # 2. Pythonファイルの中身を読み込んで、実行可能なスクリプトとしてパッケージ化
  #    ./scripts/markthesedown.py はこの home.nix からの相対パスです
  markthesedown = pkgs.writeScriptBin "markthesedown" ''
    #!${pkgs.bash}/bin/bash
    exec ${tar-map}/bin/tar-map --jobs 4 --timeout 300 -- ${pkgs.python313Packages.markitdown}/bin/markitdown {} -o {}.md
  '';

  make-videos-under-15min = pkgs.writeScriptBin "make-videos-under-15min" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        INPUT_DIR=""
        OUTPUT_DIR=""
        JOBS=4

        while [[ $# -gt 0 ]]; do
          case "$1" in
            -h|--help)
              cat <<'HELP'
    make-videos-under-15min - Split videos into segments under 15 minutes

    USAGE:
      make-videos-under-15min -i ./videos -o ./output
      make-videos-under-15min -i . -o ./splitted
      make-videos-under-15min -i . -o ./splitted -j 8

    DESCRIPTION:
      Splits video files into segments of maximum 14:50 duration.
      Output files are named with the original filename plus a 3-digit suffix.

    OPTIONS:
      -i <dir>      Input directory (required, searches for video files recursively)
      -o <dir>      Output directory (required)
      -j <n>        Number of parallel jobs (default: 4)
      -h, --help    Show this help message

    SUPPORTED FORMATS:
      mp4, mov, avi, mkv, flv, wmv, webm

    NOTES:
      - Uses ffmpeg's stream copy mode for fast processing
      - Resets timestamps for each segment
    HELP
              exit 0
              ;;
            -i) INPUT_DIR="$2"; shift 2 ;;
            -o) OUTPUT_DIR="$2"; shift 2 ;;
            -j) JOBS="$2"; shift 2 ;;
            *)
              echo "Error: Unknown option '$1'" >&2
              echo "Use --help for usage information" >&2
              exit 1
              ;;
          esac
        done

        [[ -z "$INPUT_DIR" ]] && { echo "Error: -i <input_dir> is required" >&2; exit 1; }
        [[ -z "$OUTPUT_DIR" ]] && { echo "Error: -o <output_dir> is required" >&2; exit 1; }

        mkdir -p "$OUTPUT_DIR"

        MAX_DURATION=890  # 14:50 in seconds

        ${pkgs.findutils}/bin/find "$INPUT_DIR" -type f \( \
          -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o \
          -iname "*.mkv" -o -iname "*.flv" -o -iname "*.wmv" -o \
          -iname "*.webm" \) -print0 | \
        ${pkgs.findutils}/bin/xargs -0 -P "$JOBS" -I {} ${pkgs.bash}/bin/bash -c '
          input_file="$1"
          output_dir="$2"
          max_dur="$3"

          duration=$(${pkgs.ffmpeg}/bin/ffprobe -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null | cut -d. -f1)

          [[ -z "$duration" ]] && duration=0

          if [[ "$duration" -le "$max_dur" ]]; then
            echo "[make-videos-under-15min] Skipping (under 15min): $input_file" >&2
          else
            basename="$(basename "$input_file")"
            output_base="$output_dir/$basename"
            echo "[make-videos-under-15min] Splitting: $input_file" >&2
            ${pkgs.ffmpeg}/bin/ffmpeg -i "$input_file" \
              -c copy -f segment \
              -segment_time 14:50 \
              -reset_timestamps 1 \
              "''${output_base}_%03d.mp4" 2>/dev/null
          fi
        ' _ {} "$OUTPUT_DIR" "$MAX_DURATION"
  '';

  gemini-rag = pkgs.writeScriptBin "gemini-rag" ''
    #!/bin/sh
    # Load secret if not in env
    if [ -z "$GEMINI_API_KEY" ] && [ -r "${config.sops.secrets.gemini_api_key.path}" ]; then
      export GEMINI_API_KEY="$(cat ${config.sops.secrets.gemini_api_key.path})"
    fi
    exec ${pkgs.deno}/bin/deno run --allow-all ${./scripts/gemini-rag.ts} "$@"
  '';

  tar-map = pkgs.writers.writeHaskellBin "tar-map" {
    libraries = with pkgs.haskellPackages; [
      protolude
      text
      process
      directory
      filepath
      tar
      optparse-applicative
      safe-exceptions
      bytestring
      time
      async
      stm
    ];
  } (builtins.readFile ./scripts/tar-map.hs);

  # スクレイピング・URL収集用環境
  webScrapingPythonEnv = pkgs.python313.withPackages (ps: [
    ps.requests
    ps.beautifulsoup4
    ps.trafilatura
    ps.slack-sdk
  ]);

  urls-under = pkgs.writeScriptBin "urls-under" ''
    #!${webScrapingPythonEnv}/bin/python
    ${builtins.readFile ./scripts/urls-under.py}
  '';

  url2content = pkgs.writers.writeHaskellBin "url2content" {
    libraries = with pkgs.haskellPackages; [
      req
      text
      protolude
      safe-exceptions
      process
      modern-uri
    ];
  } (builtins.readFile ./scripts/url2content.hs);

  lines2tar = pkgs.writers.writeHaskellBin "lines2tar" {
    libraries = with pkgs.haskellPackages; [
      protolude
      text
      tar
      bytestring
    ];
  } (builtins.readFile ./scripts/lines2tar.hs);

  # Pipeline: urls-under (1→N) | lines2tar (Lines→Tar) | tar-map --stdio (Functor) | tar2dir (Sink)
  save-site = pkgs.writeScriptBin "save-site" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    : "''${1:?Usage: save-site <output-dir> [urls...]}"
    OUTPUT_DIR="$1"; shift

    ([ $# -gt 0 ] && printf '%s\n' "$@" || cat) \
      | ${pkgs.findutils}/bin/xargs -I {} ${urls-under}/bin/urls-under {} 2>/dev/null \
      | sort -u \
      | ${lines2tar}/bin/lines2tar \
      | ${tar-map}/bin/tar-map --stdio --jobs 4 --timeout 300 -- ${url2content}/bin/url2content \
      | ${tar2dir}/bin/tar2dir "$OUTPUT_DIR"
  '';

  download-slack-channel-files = pkgs.writeScriptBin "download-slack-channel-files" ''
    #!${webScrapingPythonEnv}/bin/python
    ${builtins.readFile ./scripts/download-slack-channel-files.py}
  '';

  flatten-dir = pkgs.writeScriptBin "flatten-dir" ''
    #!${pkgs.python313}/bin/python
    ${builtins.readFile ./scripts/flatten-dir.py}
  '';

  cat-all = pkgs.writeScriptBin "cat-all" ''
    #!${pkgs.python313}/bin/python
    ${builtins.readFile ./scripts/cat-all.py}
  '';

  # Tar stream sink: stdin tar → filesystem directory (with mkdir -p)
  tar2dir = pkgs.writeScriptBin "tar2dir" ''
    #!${pkgs.bash}/bin/bash
    : "''${1:?Usage: tar2dir <output-dir>}"
    mkdir -p "$1" && exec ${pkgs.gnutar}/bin/tar xf - -C "$1"
  '';
in
{
  # ========================================
  # SOPS: Secrets Management
  # ========================================
  sops = {
    # Age 秘密鍵のパス (手動で設置済み)
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    # 暗号化された secrets ファイル
    defaultSopsFile = secretsFile;

    # 復号されたシークレットの定義
    secrets = {
      openrouter_api_key = { };
      gemini_api_key = { };
      anthropic_api_key = { };
    };
  };

  # sops-nix launchd service needs PATH to find getconf
  launchd.agents.sops-nix.config.EnvironmentVariables.PATH =
    lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = userConfig.username;
  home.homeDirectory = "/Users/${userConfig.username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  home.stateVersion = "24.05";

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # nix tools
    nixfmt
    nil
    sops
    deno # Explicitly add deno for TS execution

    nixos-generators

    # Development tools
    tmux
    nodejs # Node.js runtime (was: node)
    bun # Fast JavaScript runtime and package manager
    # haskell-language-server
    # ghc
    # hlint
    # cabal-install
    # zlib
    # haskellPackages.zlib
    # pkg-config

    # Media processing tools
    ffmpeg # Video/audio processing (was: ffmpeg)
    imagemagick # Image manipulation (was: imagemagick)
    poppler # PDF utilities (was: poppler)
    python313Packages.markitdown
    python313Packages.markitdown
    markthesedown
    make-videos-under-15min
    urls-under
    url2content
    lines2tar
    tar2dir
    save-site
    # webScrapingPythonEnv # This might be needed if trafilatura is not standalone
    python313Packages.trafilatura # Ensure trafilatura CLI is available
    download-slack-channel-files
    flatten-dir
    cat-all
    gemini-rag
    tar-map

    # Screen & Audio Recording
    # screenpipe

    # System utilities
    fdupes # Find duplicate files (was: fdupes)
    yt-dlp # YouTube downloader (was: yt-dlp)
    openvpn

    # former node packages
    codex

    # gui apps
    hidden-bar
    utm
    transmission_4

  ];

  # Managed dotfiles (prompts, settings, skills)
  home.file = {
    # Gemini
    ".gemini/GEMINI.md".text = import ./lib/expand-template.nix { inherit lib; } {
      templateScope = ./prompt;
      template = ./prompt/antigravity.md;
    };

    # Claude Code
    ".claude/CLAUDE.md".text = import ./lib/expand-template.nix { inherit lib; } {
      templateScope = ./prompt;
      template = ./prompt/claude-code/claude.md;
    };
    ".claude/settings.json".text = builtins.toJSON {
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };
      teammateMode = "tmux";
      permissions = {
        allow = [
          "Bash(grep:*)"
          "Bash(find:*)"
          "Bash(cat:*)"
          "Bash(ls:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(wc:*)"
          "Bash(sed:*)"
          "Bash(rg:*)"
          "Bash(fd:*)"
          "Bash(tree:*)"
          "Bash(echo:*)"
          "Bash(git log*)"
          "Bash(git diff*)"
          "Bash(git status*)"
          "Bash(git show*)"
          "Read"
          "Write"
          "WebSearch"
          "WebFetch"
        ];
      };
    };

    # Cursor
    ".cursorrules".text = import ./lib/expand-template.nix { inherit lib; } {
      templateScope = ./prompt;
      template = ./prompt/cursor.md;
    };
  }
  // (
    let
      expandTemplatesDir = import ./lib/expand-templates-dir.nix { inherit pkgs lib; };
      skillsDir = ./prompt/claude-code/skills;
      entries = builtins.readDir skillsDir;
      skillNames = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
    in
    builtins.listToAttrs (
      map (name: {
        name = ".claude/skills/${name}";
        value.source = expandTemplatesDir {
          templateScope = ./prompt;
          src = skillsDir + "/${name}";
        };
      }) skillNames
    )
  );

  # Programs configuration
  programs = {
    # Enable and configure git
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

    # Enable and configure zsh
    zsh =
      let
        gitPromptScript = ./scripts/git-prompt.sh;
      in
      {
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

              # ssh agent
              ssh-add >/dev/null 2>/dev/null
              ssh-add --apple-use-keychain ~/.ssh/github >/dev/null 2>/dev/null

              # Load secrets from sops-nix (Layer 2: Wiring)
              # File -> Environment Variable conversion
              [[ -r "${config.sops.secrets.openrouter_api_key.path}" ]] && \
                export OPENROUTER_API_KEY="$(cat ${config.sops.secrets.openrouter_api_key.path})"
              [[ -r "${config.sops.secrets.gemini_api_key.path}" ]] && \
                export GEMINI_API_KEY="$(cat ${config.sops.secrets.gemini_api_key.path})"
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

  services.ollama.enable = true;

  # Environment variables
  home.sessionVariables = {
    MANPATH = ":/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/share/man";
    SHELL = "zsh";
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";
    # Sops Key Location (Global)
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  #Settings
  targets.darwin.defaults."com.apple.dock".autohide = true;
  targets.darwin.defaults."com.apple.dock".orientation = "bottom";
  targets.darwin.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  targets.darwin.defaults."com.apple.finder" = {
    FXPreferredViewStyle = "clmv";
    _FXShowPosixPathInTitle = true;
  };
}
