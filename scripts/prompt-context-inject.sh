#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook.
#
# stdin  JSON : Claude hook payload
# stdout JSON : hookSpecificOutput with a compact Scrapbox candidate menu
#
# The hook injects only titles and one-line stubs. Page bodies stay outside the
# prompt until the agent explicitly fetches the relevant page with cosense-fetch.
set -uo pipefail

[ "${CLAUDE_AUTO_TITLE:-}" = "1" ] && exit 0

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$PROMPT" ] && exit 0

[ -z "${SCRAPBOX_SID:-}" ] && exit 0

FETCH="${COSENSE_FETCH:-$HOME/.local/bin/cosense-fetch}"
[ -x "$FETCH" ] || exit 0

# Latency gate (2026-06-22): extract ONLY explicit reference markers — Japanese quotes
# 「」『』, "double"/'single' quotes, #tags, and CamelCase/UPPER identifiers. Bare kanji/
# katakana runs were removed so plain prose and acknowledgements ("了解", "続けて",
# "fix the parser") no longer trigger the 3-project Scrapbox fan-out on EVERY message
# (UserPromptSubmit is synchronous and blocks the prompt). Marker-less prompts yield no
# candidates and exit at the `[ -z "$CANDS" ]` check below.
CANDS=$(printf '%s' "$PROMPT" \
  | grep -oE '「[^」]+」|『[^』]+』|"[^"]+"|'"'"'[^'"'"']+'"'"'|[A-Z][A-Za-z0-9_-]{2,}|#[^[:space:]　]+' 2>/dev/null \
  | sed -E 's/^[「『"#'"'"']//; s/["」』'"'"']$//' \
  | grep -vE '^(こと|それ|これ|ため|もの|よう|とき|さん|やつ|today|http|https|TODO|NOTE)$' \
  | awk '{ if (length($0) >= 2) print }' \
  | sort -u \
  | head -5)
[ -z "$CANDS" ] && exit 0

PROJECTS=(plural-reality tkgshn-private takalog)
TMPD=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$TMPD"' EXIT

search_one() {
  "$FETCH" -s "$1" -p "$2" -l 6 2>/dev/null \
    | jq -r --arg p "$2" --arg q "$1" '
        ($q | ascii_downcase) as $ql
        | (.pages // [])
        | map(. + {_score: ((if ((.title // "") | ascii_downcase | contains($ql)) then 10 else 0 end) + (.pageRank // 0))})
        | sort_by(-._score)
        | .[0:2][]
        | . as $pg
        | (($pg.lines // [])[1] // ($pg.lines // [])[0] // "")
        | gsub("^\\[\\( *"; "")
        | gsub("[\\[\\]]"; "")
        | gsub("\\s+"; " ")
        | "- " + $pg.title + " (" + $p + "): " + (.[0:80])
      ' 2>/dev/null
}

PIDS=()
i=0
while IFS= read -r term; do
  [ -z "$term" ] && continue
  for proj in "${PROJECTS[@]}"; do
    ( search_one "$term" "$proj" > "$TMPD/$i.out" 2>/dev/null ) &
    PIDS+=($!)
    i=$((i + 1))
  done
done <<< "$CANDS"

DEADLINE=$(( $(date +%s) + ${PROMPT_CONTEXT_DEADLINE:-5} ))
while :; do
  running=0
  for p in "${PIDS[@]}"; do
    kill -0 "$p" 2>/dev/null && { running=1; break; }
  done
  [ "$running" -eq 0 ] && break
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    for p in "${PIDS[@]}"; do
      kill -TERM "$p" 2>/dev/null || true
    done
    break
  fi
  sleep 0.2
done

MENU=$(cat "$TMPD"/*.out 2>/dev/null \
  | awk 'NF' \
  | grep -vE "background: ?'?#|padding:|margin:|serviceworker|\.js:[0-9]+|console\.(log|error)|=> \{|function ?\(" \
  | awk -F'): ' '!seen[$1]++' \
  | head -10)
[ -z "$MENU" ] && exit 0

CTX=$(printf '%s\n%s' \
  "[Scrapbox 関連ページ候補(自動・タイトルのみ。全文が要るものは cosense-fetch \"タイトル\" -p PROJECT -h 2 で取得)]" \
  "$MENU")

jq -cn --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$c}}'
