#!/usr/bin/env bash
# yt-transcript.sh — YouTube URL を受け取り、整形済みトランスクリプト(プレーンテキスト)を stdout に出す純粋フィルタ。
#
#   f(url) -> text on stdout
#
# 手動字幕(en/ja)を優先し、無ければ自動生成字幕にフォールバック。
# 中間ファイルは ephemeral な mktemp -d に置き、終了時に必ず消す(副作用ゼロ)。
# API キー不要(yt-dlp が字幕トラックを直接引く)。
#
# Usage:  yt-transcript.sh <youtube-url>
#         yt-transcript.sh <url> | your-summarizer
#
# ponytail: 重複除去は「連続する同一行を落とす」だけの素朴版。
#   YouTube の rolling caption(1語ずつずれて全文再掲)には十分効くが、
#   非連続の重複までは畳まない。壊れたら python 側の dedup を LCS 方式に上げる。
set -euo pipefail

readonly url="${1:?usage: yt-transcript.sh <youtube-url>}"
readonly work="$(mktemp -d "${TMPDIR:-/tmp}/yt-transcript.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# --- 字幕取得: 手動優先 → 自動フォールバック ------------------------------
# yt-dlp は手動字幕を --write-subs、自動字幕を --write-auto-subs で書く。
# まず手動を試し、ファイルが無ければ自動を引く。en を第一、ja を第二候補に。
dl() { # $1 = extra flag (--write-subs | --write-auto-subs)
  # VTT を直接引く(--convert-subs は ffmpeg 依存で不安定なので使わない)。
  yt-dlp --no-update --skip-download --quiet --no-warnings \
    "$1" --sub-langs "en.*,ja.*" --sub-format vtt \
    -o "$work/cap.%(ext)s" "$url" >/dev/null 2>&1 || true
}

dl --write-subs
compgen -G "$work/cap*.vtt" >/dev/null || dl --write-auto-subs
compgen -G "$work/cap*.vtt" >/dev/null || {
  echo "yt-transcript: no captions (manual or auto) found for: $url" >&2
  exit 3
}

# --- VTT -> 重複除去プレーンテキスト --------------------------------------
python3 - "$work" <<'PY'
import re, sys, glob, os
work = sys.argv[1]
# en を優先、無ければ最初に見つかった言語
vtts = sorted(glob.glob(os.path.join(work, "cap*.vtt")))
en = [f for f in vtts if ".en" in os.path.basename(f)]
path = (en or vtts)[0]
lines = open(path, encoding="utf-8").read().splitlines()
out = []
for l in lines:
    l = l.strip()
    if not l or l.isdigit() or "-->" in l:
        continue
    if l.startswith(("WEBVTT", "Kind:", "Language:", "NOTE")):
        continue
    l = re.sub(r"<[^>]+>", "", l)          # inline タイミングタグ除去
    l = re.sub(r"&nbsp;", " ", l).strip()
    if not l or (out and out[-1] == l):     # 連続重複を落とす
        continue
    out.append(l)
sys.stdout.write("\n".join(out) + "\n")
PY
