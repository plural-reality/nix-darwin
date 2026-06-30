#!/usr/bin/env bash
# claude-log-to-scb — ChatGPT differential sync: real-Chrome same-origin poll for
# new/changed ChatGPT conversations → takalog (会話ページ). Mirrors sync.sh.
#
# Acquisition rides the user's logged-in Chrome (chrome_fetch.py); requires the
# one-time Chrome toggle: View ▸ Developer ▸ "Allow JavaScript from Apple Events".
# With no new conversations it polls and exits early.
#
# Usage: chatgpt-sync.sh                      # chrome delta → takalog
#        chatgpt-sync.sh --full              # refetch every conversation
#        chatgpt-sync.sh --source export PATH # PATH A: official export ZIP/dir
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
export SCRAPBOX_SID="$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json'))).get('env',{}).get('SCRAPBOX_SID',''))")"

CONV_DIR="$HOME/.claude/.cache/claude-log-to-scb/conv-chatgpt"
EXTRACTED="$HOME/.claude/.cache/claude-log-to-scb/extracted-chatgpt.jsonl"

if [[ "${1:-}" == "--source" && "${2:-}" == "export" ]]; then
  BUILD=(--source export --path "${3:?export path required}")
else
  BUILD=(--source chrome); [[ "${1:-}" == "--full" ]] && BUILD+=(--full)
fi

echo "== build (acquire + flatten) =="
DEST="$(python3 "$S/chatgpt.py" build "${BUILD[@]}")"
if [[ -z "$DEST" ]]; then
  echo "no new/changed conversations — nothing to sync."
  exit 0
fi

echo "== extract (haiku, incremental) =="
python3 "$S/extract.py" --conv-dir "$CONV_DIR" --out "$EXTRACTED"
echo "== render (会話ページ → takalog) =="
python3 "$S/chatgpt.py" render --project takalog
echo "== done =="
