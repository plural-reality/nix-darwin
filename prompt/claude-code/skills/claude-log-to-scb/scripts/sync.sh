#!/usr/bin/env bash
# claude-log-to-scb — full differential sync: poll claude.ai's internal API for
# new/changed conversations → takalog Scrapbox (会話ページ + 人物/案件ページ).
# Idempotent: with no new conversations it polls and exits early.
#
# Auth rides Claude Desktop's live session (claude_cookies.py); first run pops a
# Keychain prompt — approve "Always Allow" so launchd runs work later.
#
# Usage: sync.sh            # poll delta → takalog
#        sync.sh --full     # rebuild everything from the full archive
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
LIVE="$HOME/.claude/data/claude-export/live"
export SCRAPBOX_SID="$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json'))).get('env',{}).get('SCRAPBOX_SID',''))")"

POLL_ARGS=(); [[ "${1:-}" == "--full" ]] && POLL_ARGS+=(--full)

echo "== poll =="
# bash 3.2 (/bin/bash) では「空配列 + set -u」で "${POLL_ARGS[@]}" が unbound エラーになる。
# ${arr[@]+"${arr[@]}"} は空なら何も展開せず、要素ありなら各要素を安全に渡す(bash 3.2/5.x 両対応)。
DEST="$(python3 "$S/poll.py" ${POLL_ARGS[@]+"${POLL_ARGS[@]}"})"
if [[ -z "$DEST" ]]; then
  echo "no new/changed conversations — nothing to sync."
  exit 0
fi

echo "== split =="
python3 "$S/split.py" "$LIVE"
echo "== extract (haiku, incremental) =="
python3 "$S/extract.py"
echo "== ingest (会話ページ) =="
python3 "$S/ingest.py" "$LIVE" --project takalog
echo "== aggregate (人物/案件ページ) =="
python3 "$S/aggregate_and_upsert.py" --project takalog --min-mentions 2
echo "== done =="
