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
    (ps.slack-sdk.overridePythonAttrs (_: {
      doCheck = false;
    }))
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
        DELETE_ORIGINALS=0

        while [[ $# -gt 0 ]]; do
          case "$1" in
            -h|--help)
              cat <<'HELP'
    make-videos-under-15min - Split videos into segments under 15 minutes

    USAGE:
      make-videos-under-15min -i ./videos -o ./output
      make-videos-under-15min -i . -o . -d
      make-videos-under-15min -i . -o ./splitted -j 8

    DESCRIPTION:
      Splits video files into segments of maximum 14:50 duration.
      Output files are named with the original filename plus a 3-digit suffix.

    OPTIONS:
      -i <dir>      Input directory (required, searches for video files recursively)
      -o <dir>      Output directory (required)
      -j <n>        Number of parallel jobs (default: 4)
      -d, --delete-originals  Delete original files after successful splitting
      -h, --help    Show this help message

    SUPPORTED FORMATS:
      mp4, mov, avi, mkv, flv, wmv, webm

    NOTES:
      - Uses ffmpeg's stream copy mode for fast processing
      - Resets timestamps for each segment
      - -d only removes files that were actually split (>15min)
    HELP
              exit 0
              ;;
            -i) INPUT_DIR="$2"; shift 2 ;;
            -o) OUTPUT_DIR="$2"; shift 2 ;;
            -j) JOBS="$2"; shift 2 ;;
            -d|--delete-originals) DELETE_ORIGINALS=1; shift ;;
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
          delete_flag="$4"

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
              "''${output_base}_%03d.mp4" 2>/dev/null \
            && [[ "$delete_flag" -eq 1 ]] && {
              echo "[make-videos-under-15min] Deleting original: $input_file" >&2
              rm "$input_file"
            }
          fi
        ' _ {} "$OUTPUT_DIR" "$MAX_DURATION" "$DELETE_ORIGINALS"
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
    runtimeInputs = with pkgs; [
      fzf
      jq
      coreutils
      gnused
    ];
    text = builtins.readFile ../scripts/claude-history.sh;
  };

  # freee REST filter: stdin JSON -> freee API -> stdout JSON.
  # Auth state stays in ~/.config/freee-mcp, owned by freee-mcp's OAuth flow.
  freeeCall = pkgs.writeShellApplication {
    name = "freee-call";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      exec ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${../scripts/freee-call.ts} "$@"
    '';
  };

  # freee 口座照合: 残高 vs 登録済み仕訳の差分を1コールに畳む。
  # freee-call を合成して transport を再利用する (auth を二重に持たない)。
  freeeReconcile = pkgs.writeShellApplication {
    name = "freee-reconcile";
    runtimeInputs = [
      freeeCall
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ../scripts/freee-reconcile.sh;
  };

  # Fable advisor transport: stdin brief -> validated response on stdout.
  # JSON framing makes an empty successful CLI exit observable; bounded attempts
  # and one retry prevent a stalled Fable process from blocking the caller.
  # The adapter's default per-attempt deadline is 15 minutes because Fable's
  # max-effort long-form consultations routinely take several minutes.
  fableConsult = pkgs.writeShellApplication {
    name = "fable-consult";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.llm-agents.claude-code
    ];
    text = builtins.readFile ../scripts/fable-consult.sh;
  };

  # Codex thread naming adapter: argv -> app-server protocol -> thread name.
  codexName = pkgs.writeShellApplication {
    name = "codex-name";
    runtimeInputs = [
      pkgs.nodejs_22
      pkgs.llm-agents.codex
    ];
    text = ''
      exec ${pkgs.nodejs_22}/bin/node --experimental-strip-types ${../scripts/codex-name.ts} "$@"
    '';
  };

  # Read-only Codex task metadata audit: JSON stream -> JSON/Markdown candidates.
  codexTaskAudit = pkgs.writeShellApplication {
    name = "codex-task-audit";
    runtimeInputs = [ pkgs.nodejs_22 ];
    text = ''
      exec ${pkgs.nodejs_22}/bin/node --disable-warning=ExperimentalWarning --experimental-strip-types --experimental-sqlite ${../scripts/codex-task-audit.ts} "$@"
    '';
  };

  # Read-only Mori MCP adapter. OAuth/runtime state remains outside Nix.
  mori = pkgs.writeShellApplication {
    name = "mori";
    runtimeInputs = [ pkgs.python313 ];
    text = ''
      exec "$HOME/.claude/scripts/mori.py" "$@"
    '';
  };

  # One schedule target for Mori, Limitless, and the official Plaud CLI.
  transcriptSync = pkgs.writeShellApplication {
    name = "transcript-sync";
    runtimeInputs = [ pkgs.python313 ];
    text = ''
      exec "$HOME/.claude/scripts/transcript-sync.py" "$@"
    '';
  };

  # Read-only iMessage history client. It only speaks the fixed JSON/JSONL
  # protocol to a per-user signed bridge; Full Disk Access never belongs here.
  imsgHistory = pkgs.writeShellApplication {
    name = "imsg-history";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      netcat
      openssh
    ];
    text = builtins.readFile ../scripts/claude/imsg-history/imsg-history.sh;
  };

  # Read-only Apple Photos client. The stable signed bridge owns Photos TCC;
  # this client only speaks the fixed JSON/JSONL protocol over a mode-0600 socket.
  photoLibrary = pkgs.writeShellApplication {
    name = "photo-library";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      netcat
    ];
    text = builtins.readFile ../scripts/claude/photo-library/photo-library.sh;
  };

  # Weekly snapshot-difference driver. PhotoKit/Vision remain inside the signed
  # bridge; this outer launcher owns only minimal local manifests and review jobs.
  photoCardScan = pkgs.writeShellApplication {
    name = "photo-card-scan";
    runtimeInputs = [
      pkgs.python3
      photoLibrary
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${../scripts/claude/photo-library/photo-card-scan.py} "$@"
    '';
  };

  nixApply = pkgs.writeScriptBin "nix-apply" ''
    #!${pkgs.bash}/bin/bash
    exec ${../scripts/nix-apply.sh} "$@"
  '';

  appleNotesToScrapbox = pkgs.writeScriptBin "apple-notes-to-scrapbox" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.nodejs}/bin/node ${../scripts/apple-notes-to-scrapbox.mjs} "$@"
  '';

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
    cp -Lf "$SBDIR/scrapbox-write.mjs" "$SBDIR/_run.mjs" 2>/dev/null || true
    exec ${pkgs.python3}/bin/python3 "$HOME/.claude/scripts/lib/scrapbox_session.py" exec \
      ${pkgs.nodejs}/bin/node "$SBDIR/_run.mjs" "$@"
  '';

  # ── Scrapbox renamer ────────────────────────────────────
  # Sibling of scrapbox-write: renames a page in place (preserving its ID &
  # history) and repoints every backlink form — plain, deep ([#anchor]), icon,
  # and #hashtag — to the new title. Reuses the same managed @cosense/std
  # node_modules, and the same writable-copy dance to dodge ESM symlink resolution.
  scrapbox-rename = pkgs.writeScriptBin "scrapbox-rename" ''
    #!${pkgs.bash}/bin/bash
    SBDIR="$HOME/.local/share/scrapbox-write"
    cp -Lf "$SBDIR/scrapbox-rename.mjs" "$SBDIR/_run_rename.mjs" 2>/dev/null || true
    exec ${pkgs.python3}/bin/python3 "$HOME/.claude/scripts/lib/scrapbox_session.py" exec \
      ${pkgs.nodejs}/bin/node "$SBDIR/_run_rename.mjs" "$@"
  '';
  # ── GTD Canvas ──────────────────────────────────────────
  # Scrapbox の ToDoカンバンを付箋レイアウトで見せ、ドラッグでの移動を CAS 付きで
  # Scrapbox へ書き戻すローカルサーバ。読み取り(gtd-fetch/gtd-external)と描画(gtd-canvas)は
  # 純粋関数で、副作用はこのサーバの POST /move だけに閉じている。
  # ディレクトリごと1つの store path へ置くのは、ESM の相対 import を realpath 基準で
  # 解決させるため(ファイル単位の symlink だと兄弟モジュールを見失う)。
  gtd-canvas-serve = pkgs.writeScriptBin "gtd-canvas-serve" ''
    #!${pkgs.bash}/bin/bash
    # launchd の最小 PATH では cosense-fetch / scrapbox-write / scrapbox-rename / evkit /
    # jq / curl が見えないので明示注入する。
    export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:$PATH"
    export LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8
    exec ${pkgs.nodejs}/bin/node "$HOME/.local/share/gtd-canvas/bin/gtd-serve.mjs" "$@"
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
    freeeCall
    freeeReconcile
    fableConsult
    codexName
    codexTaskAudit
    mori
    transcriptSync
    imsgHistory
    photoLibrary
    photoCardScan
    nixApply
    appleNotesToScrapbox

    # Scrapbox writer
    scrapbox-write
    scrapbox-rename

    # GTD Canvas server
    gtd-canvas-serve

    # CLI tools used by scripts
    pkgs.python313Packages.markitdown
    pkgs.python313Packages.trafilatura
  ];

  # `home-manager.useUserPackages` の system profile 切替は root 権限を要する。
  # 同じNix derivationを user-owned launcher layerにも投影し、Home Manager単独の
  # activation直後から古い `/etc/profiles/per-user` を経由せず利用可能にする。
  home.file.".local/bin/scrapbox-write".source = "${scrapbox-write}/bin/scrapbox-write";
  home.file.".local/bin/scrapbox-rename".source = "${scrapbox-rename}/bin/scrapbox-rename";
  home.file.".local/bin/photo-library".source = "${photoLibrary}/bin/photo-library";
  home.file.".local/bin/gtd-canvas-serve".source = "${gtd-canvas-serve}/bin/gtd-canvas-serve";

  # ディレクトリ丸ごと1つの store path。ファイル単位の symlink にすると、ESM が
  # realpath 基準で兄弟 import を解決できず gtd-canvas.mjs を見失う。
  home.file.".local/share/gtd-canvas/bin".source = ../scripts/claude/gtd;

  # prompt-review collector (nix-shell shebang, self-contained)
  home.file.".local/bin/prompt-review-collect" = {
    source = ../prompt/claude-code/skills/prompt-review/scripts/collect.py;
    executable = true;
  };

  # cosense-fetch: Scrapbox (Cosense) read CLI — Smart Context via proxy (-h),
  # full-text search (-s) and raw page JSON (-r) via connect.sid. Pure bash;
  # deps (curl/jq/base64) resolve from PATH. Source: scripts/cosense-fetch.
  home.file.".local/bin/cosense-fetch" = {
    source = ../scripts/cosense-fetch;
    executable = true;
  };

  # wip-crawl: detects the unprocessed [claude code WIP.icon] queue across the
  # 3 Scrapbox projects (pure filter; node shebang, shells out to cosense-fetch).
  # Source: scripts/wip-crawl.mjs. Tested by scripts/wip-crawl.test.mjs.
  home.file.".local/bin/wip-crawl" = {
    source = ../scripts/wip-crawl.mjs;
    executable = true;
  };

  # scb-lint: mechanical health Lint of the 3 Scrapbox projects (orphan / duplicate /
  # empty-stub concept pages) from page metadata (pure filter; shells out to cosense-fetch).
  # Semantic Lint + WIP filing is the /scb-lint skill. Source: scripts/scb-lint.mjs.
  # Tested by scripts/scb-lint.test.mjs.
  home.file.".local/bin/scb-lint" = {
    source = ../scripts/scb-lint.mjs;
    executable = true;
  };

  # Deploy scrapbox-write.mjs to ~/.local/share/scrapbox-write/
  home.file.".local/share/scrapbox-write/scrapbox-write.mjs".source = ../scripts/scrapbox-write.mjs;
  # scrapbox-rename shares the same dir (and its @cosense/std node_modules).
  home.file.".local/share/scrapbox-write/scrapbox-rename.mjs".source = ../scripts/scrapbox-rename.mjs;
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
