#!/usr/bin/env bash
# session-auto-title.sh — SessionStart hook (matcher: startup | resume)
#
# 目的: セッション起動時に cwd/git ブランチから日本語タイトルを設定する。
#       プロジェクト名 + ブランチ名の形式。
#       startup の場合のみ発火 (clear/compact は無視)。
#
# Output: hookSpecificOutput.sessionTitle を含む JSON
set -uo pipefail

readonly INPUT="$(cat 2>/dev/null || true)"
readonly SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null || true)"
readonly CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"

# startup / resume のみ処理
case "$SOURCE" in
  startup|resume) ;;
  *) echo '{}'; exit 0 ;;
esac

[ -z "$CWD" ] && echo '{}' && exit 0

make_title() {
  local cwd="$1"
  local proj branch title

  # git ルートのベース名を取得
  proj="$(cd "$cwd" && git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || basename "$cwd")"
  branch="$(cd "$cwd" && git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    title="${proj}/${branch}"
  else
    title="$proj"
  fi

  # 30文字でカット
  printf '%s' "$title" | cut -c1-30
}

title="$(make_title "$CWD")"
[ -z "$title" ] && echo '{}' && exit 0

# tmux セッション名も更新 (cc-xxxx → project/branch)
if [ -n "${TMUX:-}" ]; then
  tmux rename-session "$title" 2>/dev/null || true
  tmux set-window-option automatic-rename off 2>/dev/null || true
fi

jq -n --arg t "$title" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    sessionTitle: $t
  }
}'
