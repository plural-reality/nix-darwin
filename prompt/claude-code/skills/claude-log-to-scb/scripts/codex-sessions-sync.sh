#!/usr/bin/env bash
# One-way projection: host-local Codex rollouts -> TakaLog summaries.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
CACHE="$HOME/.claude/.cache/claude-log-to-scb"
export SCRAPBOX_SID="$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json'))).get('env',{}).get('SCRAPBOX_SID',''))")"

python3 "$S/sessions.py" build --source codex
python3 "$S/extract.py" \
  --conv-dir "$CACHE/conv-codex-sessions" \
  --out "$CACHE/extracted-codex-sessions.jsonl"
python3 "$S/sessions.py" render --source codex --project takalog "$@"
