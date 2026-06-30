#!/usr/bin/env bash
# auto-rename-from-prompt.sh — UserPromptSubmit hook (同期)
#
# 目的: セッションタイトルを tmux セッション名 / OSC 端末タイトル / Claude Code の
#       custom-title に反映する。表示は custom-title が ai-title(英語・本体生成)より
#       優先されるため、ここで日本語タイトルを与えるとピッカーもタブも日本語化される。
#
# 二段構え (初回応答を遅らせないため):
#   Stage 1 (本hook・同期・即時): 初回プロンプト先頭20字を「仮タイトル」として即反映。
#   Stage 2 (session-title-refine.sh・非同期): Haiku が日本語タイトルを生成しキャッシュへ。
#            本hookが次以降の UserPromptSubmit で「一度だけ」回収して custom-title を差し替える。
#
# 設計原則:
#   - fail-open: あらゆる失敗で空 JSON + exit (プロンプトを決してブロックしない)。
#   - apply-once: 洗練タイトルの反映は1回だけ。以後の手動 /rename を上書きしない。
#   - 再帰防止: Haiku 生成用の子 claude は CLAUDE_AUTO_TITLE=1 で起動 → 本hook冒頭で握りつぶす。
set -uo pipefail

# --- 再帰ガード: タイトル生成用 claude 自身の UserPromptSubmit を無視 ---
[ "${CLAUDE_AUTO_TITLE:-}" = "1" ] && { echo '{}'; exit 0; }

readonly INPUT="$(cat 2>/dev/null || true)"
readonly PROMPT="$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || true)"
readonly TRANSCRIPT="$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || true)"
readonly SID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
readonly CACHE_DIR="$HOME/.claude/.cache/session-titles"

# タイトル正規化: 改行除去 → 前後空白除去 → 前後の引用符/括弧はぎ取り → 24字でカット
sanitize_title() {
  printf '%s' "$1" \
    | tr -d '\n\r' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^["“”「『`]\{1,\}//' -e 's/["“”」』`]\{1,\}$//' \
    | cut -c1-24
}

# 仮タイトル: 初回プロンプト先頭20字 (Stage 1)
instant_title() {
  printf '%s' "$1" | tr -d '\n\r' | sed 's/^[[:space:]]*//' | cut -c1-20
}

# 副作用: tmux セッション名 + OSC0 端末タイトルを TITLE に揃える
apply_to_terminal() {
  if [ -n "${TMUX:-}" ]; then
    tmux rename-session "$1" 2>/dev/null || true
    tmux set-window-option automatic-rename off 2>/dev/null || true
  fi
  printf '\033]0;%s\007' "$1" > /dev/tty 2>/dev/null || true
}

# Claude Code の custom-title を設定する JSON を stdout へ
emit_session_title() {
  jq -n --arg t "$1" '{ hookSpecificOutput: { hookEventName: "UserPromptSubmit", sessionTitle: $t } }'
}

# 初回判定: transcript 無し or assistant 発言ゼロ
is_first_message() {
  [ -f "$TRANSCRIPT" ] || return 0
  # grep -c は no-match で "0" を出力しつつ exit 1 → `|| echo 0` は二重出力でバグる。`|| true` + 既定0 で吸収。
  local n; n="$(grep -c '"role":"assistant"' "$TRANSCRIPT" 2>/dev/null || true)"
  [ "${n:-0}" -eq 0 ]
}

# transcript 内の最後の custom-title (手動 /rename 検知用)
last_custom_title() {
  [ -f "$TRANSCRIPT" ] || return 0
  grep '"type":"custom-title"' "$TRANSCRIPT" 2>/dev/null | tail -1 \
    | jq -r '.customTitle // empty' 2>/dev/null || true
}

main() {
  # --- (A) 非同期生成された洗練タイトルの回収 (apply-once / 手動rename尊重) ---
  if [ -n "$SID" ] && [ -f "$CACHE_DIR/$SID.title" ] && [ ! -f "$CACHE_DIR/$SID.done" ]; then
    local refined instant_saved last_ct
    refined="$(sanitize_title "$(cat "$CACHE_DIR/$SID.title" 2>/dev/null || true)")"
    instant_saved="$(cat "$CACHE_DIR/$SID.instant" 2>/dev/null || true)"
    last_ct="$(last_custom_title)"
    touch "$CACHE_DIR/$SID.done" 2>/dev/null || true   # 反映可否によらず一度で打ち切る
    # 最後の custom-title が「我々の仮タイトル」または未設定 = まだ誰も手で変えていない → 反映
    if [ -n "$refined" ] && { [ -z "$last_ct" ] || [ "$last_ct" = "$instant_saved" ] || [ "$last_ct" = "$refined" ]; }; then
      apply_to_terminal "$refined"
      emit_session_title "$refined"
      return
    fi
    # 手動 /rename 済 → 尊重して何もしない
    echo '{}'; return
  fi

  # --- (B) 初回メッセージ: 仮タイトルを即時反映 ---
  if is_first_message; then
    [ -z "$PROMPT" ] && { echo '{}'; return; }
    local instant; instant="$(instant_title "$PROMPT")"
    [ -z "$instant" ] && { echo '{}'; return; }
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    [ -n "$SID" ] && printf '%s' "$instant" > "$CACHE_DIR/$SID.instant" 2>/dev/null || true
    apply_to_terminal "$instant"
    emit_session_title "$instant"
    return
  fi

  echo '{}'
}

main
