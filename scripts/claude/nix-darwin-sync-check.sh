#!/usr/bin/env bash
# nix-darwin-sync-check.sh — Claude Code SessionStart hook
# nix-darwin repo の git 状態を確認し、差分があれば通知する
# 失敗時は exit 0（起動をブロックしない）

set -euo pipefail

find_nix_darwin_repo() {
  # 環境変数で明示指定されていればそれを使う
  if [[ -n "${NIX_DARWIN_REPO:-}" ]] && [[ -d "$NIX_DARWIN_REPO/.git" ]]; then
    echo "$NIX_DARWIN_REPO"
    return 0
  fi
  local candidates=(
    "/private/etc/nix-darwin"
    "$HOME/nix-darwin"
    "$HOME/.config/nix-darwin"
  )
  for dir in "${candidates[@]}"; do
    if [[ -d "$dir/.git" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

REPO_DIR="$(find_nix_darwin_repo)" || exit 0

cd "$REPO_DIR"

REMOTE=$(git remote 2>/dev/null | head -1) || exit 0
[[ -z "$REMOTE" ]] && exit 0

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null) || exit 0
[[ -z "$BRANCH" ]] && exit 0

# 5秒タイムアウトで fetch
timeout 5 git fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null || true

LOCAL=$(git rev-parse HEAD 2>/dev/null) || exit 0
REMOTE_REF=$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null) || exit 0

MSG=""

if [[ "$LOCAL" != "$REMOTE_REF" ]]; then
  BEHIND=$(git rev-list --count HEAD.."$REMOTE/$BRANCH" 2>/dev/null || echo 0)
  AHEAD=$(git rev-list --count "$REMOTE/$BRANCH"..HEAD 2>/dev/null || echo 0)

  if [[ "$BEHIND" -gt 0 && "$AHEAD" -gt 0 ]]; then
    MSG="[nix-darwin] upstream と分岐: ${AHEAD} ahead, ${BEHIND} behind"
    MSG="$MSG\n  cd $REPO_DIR && git pull --rebase && ./apply"
  elif [[ "$BEHIND" -gt 0 ]]; then
    MSG="[nix-darwin] upstream に ${BEHIND} commits 遅れています"
    MSG="$MSG\n  cd $REPO_DIR && git pull && ./apply"
  elif [[ "$AHEAD" -gt 0 ]]; then
    MSG="[nix-darwin] ${AHEAD} 未 push のコミットがあります"
    MSG="$MSG\n  git -C $REPO_DIR push"
  fi
fi

# 未コミットの変更チェック
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  if [[ -n "$MSG" ]]; then
    MSG="$MSG\n[nix-darwin] 未コミットの変更もあります"
  else
    MSG="[nix-darwin] 未コミットの変更があります ($REPO_DIR)"
  fi
fi

if [[ -n "$MSG" ]]; then
  printf '%b\n' "$MSG"
fi

exit 0
