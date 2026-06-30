#!/usr/bin/env bash
# claude-threads — 全 tmux セッションのスレッド(window)を daemon(:17843) で味付けし、
# fzf で選択 → そのスレッドへジャンプする。tmux の prefix+e (display-popup) と `cs` から呼ばれる。
#
# 結合: window → activeペインの pane_id → bindings.jsonl(pane→sessionId) → /api/sessions(title)。
# binding 無い窓は cwd の basename をラベルにフォールバック。
set -euo pipefail
DAEMON="http://127.0.0.1:17843"
BINDINGS="$HOME/.claude/control/bindings.jsonl"

sessions_json="$(curl -s --max-time 1 "$DAEMON/api/sessions" 2>/dev/null || echo '{"sessions":[]}')"
FMT=$'#{session_name}\t#{window_index}\t#{pane_id}\t#{pane_current_path}'

build() {
  tmux list-windows -a -F "$FMT" 2>/dev/null \
  | while IFS=$'\t' read -r sess widx pane cwd; do
      [ -z "$sess" ] && continue
      sid="$(grep -F "\"pane\":\"$pane\"" "$BINDINGS" 2>/dev/null | tail -1 \
             | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' || true)"
      label=""
      [ -n "$sid" ] && label="$(printf '%s' "$sessions_json" \
        | jq -r --arg id "$sid" '.sessions[]? | select(.id==$id) | (.title // .lastUser // "")' 2>/dev/null || true)"
      [ -z "$label" ] && label="$(basename "$cwd")"
      # 隠しフィールド(sess,widx 選択後パース用) + 表示フィールド
      printf '%s\t%s\t%s  ⌘%s  %s\n' "$sess" "$widx" "$sess" "$widx" "$label"
    done
}

# --list: 非対話で結合結果を確認する (デバッグ/検証用)。
[ "${1:-}" = "--list" ] && { build | cut -f3-; exit 0; }

sel="$(build | fzf --delimiter='\t' --with-nth=3 --no-sort \
        --prompt='claude thread> ' --header='Enter=jump  Esc=cancel')" || exit 0
[ -z "$sel" ] && exit 0
sess="$(printf '%s' "$sel" | cut -f1)"
widx="$(printf '%s' "$sel" | cut -f2)"
[ -z "$sess" ] && exit 0

if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$sess" \; select-window -t "$sess:$widx"
else
  tmux attach -t "$sess" \; select-window -t "$sess:$widx"
fi
