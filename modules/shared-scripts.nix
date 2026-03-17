# Shared scripts: stream-oriented data transformation tools
{ pkgs, lib, ... }:
let
  # Python environment for markitdown and related processing
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

  # Python environment for web scraping / URL collection
  webScrapingPythonEnv = pkgs.python313.withPackages (ps: [
    ps.requests
    ps.beautifulsoup4
    ps.trafilatura
    (ps.slack-sdk.overridePythonAttrs (_: { doCheck = false; }))
  ]);

  # ── Haskell stream tools ──────────────────────────────────

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
  } (builtins.readFile ../scripts/tar-map.hs);

  url2content = pkgs.writers.writeHaskellBin "url2content" {
    libraries = with pkgs.haskellPackages; [
      req
      text
      protolude
      safe-exceptions
      process
      modern-uri
    ];
  } (builtins.readFile ../scripts/url2content.hs);

  lines2tar = pkgs.writers.writeHaskellBin "lines2tar" {
    libraries = with pkgs.haskellPackages; [
      protolude
      text
      tar
      bytestring
    ];
  } (builtins.readFile ../scripts/lines2tar.hs);

  # ── Shell / Python scripts ────────────────────────────────

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

  urls-under = pkgs.writeScriptBin "urls-under" ''
    #!${webScrapingPythonEnv}/bin/python
    ${builtins.readFile ../scripts/urls-under.py}
  '';

  tar2dir = pkgs.writeScriptBin "tar2dir" ''
    #!${pkgs.bash}/bin/bash
    : "''${1:?Usage: tar2dir <output-dir>}"
    mkdir -p "$1" && exec ${pkgs.gnutar}/bin/tar xf - -C "$1"
  '';

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

  flatten-dir = pkgs.writeScriptBin "flatten-dir" ''
    #!${pkgs.python313}/bin/python
    ${builtins.readFile ../scripts/flatten-dir.py}
  '';

  cat-all = pkgs.writeScriptBin "cat-all" ''
    #!${pkgs.python313}/bin/python
    ${builtins.readFile ../scripts/cat-all.py}
  '';

  download-slack-channel-files = pkgs.writeScriptBin "download-slack-channel-files" ''
    #!${webScrapingPythonEnv}/bin/python
    ${builtins.readFile ../scripts/download-slack-channel-files.py}
  '';

  # Claude Code history search (fzf-based cross-project session finder)
  ch = pkgs.writeShellApplication {
    name = "ch";
    runtimeInputs = with pkgs; [ fzf jq coreutils gnused ];
    text = builtins.readFile ../scripts/claude-history.sh;
  };

  # ── Scrapbox writer ─────────────────────────────────────
  # @cosense/std is not in nixpkgs, so we use a managed node_modules
  # directory under ~/.local/share/scrapbox-write/ with activation-time
  # npm install. The wrapper injects NODE_PATH for hermetic resolution.
  # ESM ignores NODE_PATH, so we cd into the directory where node_modules lives.
  # The mjs file is a Nix symlink in the same dir, and node resolves imports
  # relative to the realpath of the script, so we copy it to a temp location
  # alongside node_modules to ensure correct resolution.
  scrapbox-write = pkgs.writeScriptBin "scrapbox-write" ''
    #!${pkgs.bash}/bin/bash
    SBDIR="$HOME/.local/share/scrapbox-write"
    # Ensure a writable copy of the script exists next to node_modules
    # (Nix symlinks into the store break ESM resolution)
    cp -f "$SBDIR/scrapbox-write.mjs" "$SBDIR/_run.mjs" 2>/dev/null || true
    exec ${pkgs.nodejs}/bin/node "$SBDIR/_run.mjs" "$@"
  '';
in
{
  home.packages = [
    # Haskell stream tools
    tar-map
    url2content
    lines2tar

    # Shell / Python scripts
    markthesedown
    make-videos-under-15min
    urls-under
    tar2dir
    save-site
    flatten-dir
    cat-all
    download-slack-channel-files
    ch

    # Scrapbox writer
    scrapbox-write

    # CLI tools used by scripts
    pkgs.python313Packages.markitdown
    pkgs.python313Packages.trafilatura
  ];

  # Deploy scrapbox-write.mjs to ~/.local/share/scrapbox-write/
  home.file.".local/share/scrapbox-write/scrapbox-write.mjs".source = ../scripts/scrapbox-write.mjs;
  home.file.".local/share/scrapbox-write/package.json".text = builtins.toJSON {
    name = "scrapbox-write";
    version = "1.0.0";
    type = "module";
    dependencies = {
      "@cosense/std" = "^0.31.0";
    };
  };

  # Activation: npm install @cosense/std if node_modules is missing or stale
  home.activation.scrapboxWriteNpmInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    SBDIR="$HOME/.local/share/scrapbox-write"
    if [ ! -d "$SBDIR/node_modules/@cosense/std" ]; then
      ${pkgs.nodejs}/bin/npm install --prefix "$SBDIR" --no-audit --no-fund 2>/dev/null \
        && echo "scrapbox-write: npm install complete" \
        || echo "scrapbox-write: npm install failed (will retry next switch)" >&2
    fi
  '';
}
