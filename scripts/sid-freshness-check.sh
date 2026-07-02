#!/usr/bin/env bash
# Claude Code SessionStart hook.
#
# Checks the single Scrapbox session credential before a session silently loses
# read/write/search access across plural-reality, tkgshn-private, and takalog.
set -uo pipefail

[ -z "${SCRAPBOX_SID:-}" ] && exit 0

TMP=$(mktemp 2>/dev/null) || exit 0
trap 'rm -f "$TMP"' EXIT

CODE=$(curl -s -o "$TMP" -w '%{http_code}' --max-time 8 \
  -H "Cookie: connect.sid=${SCRAPBOX_SID}" \
  https://scrapbox.io/api/users/me 2>/dev/null || true)

[ -z "$CODE" ] && exit 0
[ "$CODE" = "000" ] && exit 0

if [ "$CODE" = "200" ] && ! grep -q '"isGuest":[[:space:]]*true' "$TMP"; then
  exit 0
fi

WARN="Scrapbox connect.sid が失効しています(HTTP ${CODE})。cosense-fetch / 横断検索 / Scrapbox書込が全プロジェクトで失敗します。SCRAPBOX_SID を更新してください。"
jq -cn --arg c "$WARN" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$c}}'
