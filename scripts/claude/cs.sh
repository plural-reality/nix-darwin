#!/usr/bin/env bash
# cs — Claude タブ/スレッド スイッチャ ("claude switch")
#   cs N              現セッションのタブ(window) N へフォーカス (= ⌘N と同じ)
#   cs                全セッション横断・daemon味付けの fzf 検索ジャンプ (= claude-threads)
#   cs --prune        unattached な cc-* セッションを一覧 (dry-run)
#   cs --prune --yes  実際に kill する (中の claude も道連れ)
#
# 番号体系の単一の真実 = tmux の window index。⌘N / cs N / タブバー / サイドバーが同じ番号を指す。
set -euo pipefail

prune() {
  local cands
  cands="$(tmux list-sessions -F '#{session_attached} #{session_name}' 2>/dev/null \
           | awk '$1==0 && $2 ~ /^cc-/ {print $2}')" || true
  if [ -z "$cands" ]; then echo "prune: 対象なし (unattached cc-* セッション無し)"; return 0; fi
  if [ "${1:-}" = "--yes" ]; then
    printf '%s\n' "$cands" | while read -r s; do
      [ -n "$s" ] && tmux kill-session -t "$s" 2>/dev/null && echo "killed $s"
    done
  else
    echo "prune 候補 (unattached cc-* / 中で claude が生きていれば道連れ kill):"
    printf '%s\n' "$cands" | sed 's/^/  /'
    echo
    echo "実行するには: cs --prune --yes"
  fi
}

case "${1:-}" in
  --prune) prune "${2:-}" ;;
  '')      exec claude-threads ;;
  *)       tmux select-window -t ":=$1" ;;
esac
