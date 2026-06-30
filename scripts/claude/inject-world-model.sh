#!/usr/bin/env bash
# inject-world-model.sh — Claude Code SessionStart hook (Workstream A4)
#
# ~/.claude/context/world-model.md を additionalContext として全セッションに注入する。
# nix 管理の CLAUDE.md を de-symlink せずに「3つの Scrapbox + entity→live-tool 契約」を
# 標準知識として常駐させる。安定したら CLAUDE.md Routing Table へ昇格する。
# fail-open: 失敗時は exit 0・空出力(起動をブロックしない)。
set -uo pipefail

DOC="$HOME/.claude/context/world-model.md"
[[ -r "$DOC" ]] || exit 0

CONTENT=$(cat "$DOC" 2>/dev/null || true)
[[ -z "$CONTENT" ]] && exit 0

jq -cn --arg c "$CONTENT" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$c}}'
exit 0
