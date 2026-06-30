#!/usr/bin/env bash
# claude-log-to-scb — Claude Code セッション同期(sync.sh の対。claude.ai ではなく
# ~/.claude/projects/**/*.jsonl が対象)。セッションを claude.ai と同じ会話ページ形式に
# 正規化 → takalog。build(正規化) → extract(haiku, 増分) → render(takalog 書込)。
#
# Usage: sessions-sync.sh [--dry-run] [--limit N] [--force]
#   --dry-run : render を書込なしで確認(build/extract は走る。extract は増分なので安全)
#   --limit N : render するページ数の上限
#   --force   : seen を無視して全ページ再生成
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
CACHE="$HOME/.claude/.cache/claude-log-to-scb"
export SCRAPBOX_SID="$(python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/.claude/settings.json'))).get('env',{}).get('SCRAPBOX_SID',''))")"

echo "== build (sessions → conversation shape) =="
python3 "$S/sessions.py" build
echo "== extract (haiku, incremental) =="
python3 "$S/extract.py" --conv-dir "$CACHE/conv-sessions" --out "$CACHE/extracted-sessions.jsonl"
echo "== render (takalog 会話ページ) =="
python3 "$S/sessions.py" render --project takalog "$@"
echo "== done =="
