#!/usr/bin/env bash
# crm-due-inject.sh — Claude Code SessionStart hook (Proactive CRM, PUSH surface)
#
# beeper-scrapbox-crm gateway の GET /api/crm/due を読み、能動的な「連絡候補」を
# additionalContext として注入する。モデルはこれを受けて AskUserQuestion で
# ユーザーに提示する(下書き/スヌーズ/却下)。LLM は自動送信しない・必ず人間承認。
#
# fail-open: gateway 停止 / 404 / 非JSON / items 空 → 何も出さず exit 0。
#            curl は --max-time 3 で 3 秒デッドライン。決してハングしない・非ゼロ終了しない。
#
# テスト用シーム: CRM_DUE_INPUT に /api/crm/due 形式の JSON ファイルパスを与えると
#                curl を迂回してそのファイルを入力にする(下流の変換だけを検証できる)。
set -uo pipefail
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

GATEWAY_URL="${CRM_GATEWAY_URL:-http://localhost:8787}"

# Acquire the /api/crm/due payload. -f makes HTTP >= 400 (incl. 404) yield empty
# output + nonzero exit, which falls through to the empty-guard below (fail-open).
RAW="$(
  if [ -n "${CRM_DUE_INPUT:-}" ] && [ -r "${CRM_DUE_INPUT}" ]; then
    cat "${CRM_DUE_INPUT}" 2>/dev/null || true
  else
    curl -sf --max-time 3 "${GATEWAY_URL}/api/crm/due" 2>/dev/null || true
  fi
)"

[ -z "$RAW" ] && exit 0

# Pure transform: /api/crm/due JSON -> hookSpecificOutput JSON (or empty when no
# items / invalid JSON). All Japanese + bullets are jq string literals so jq owns
# every byte of JSON construction (no manual interpolation of Japanese into JSON).
OUT="$(printf '%s' "$RAW" | jq -c '
  (.items // []) as $items
  | ($items | length) as $n
  | if ($n | not) or $n == 0 then empty
    else
      ($items[0:10]) as $top
      | ($n - ($top | length)) as $rest
      | ($top
          | map(
              "・" + (.contactName // "（名前不明）")
              + "｜" + (if .trigger == "reply" then "未返信" else "フォロー" end)
              + "｜" + (.reasonText // "")
              + "｜直近: " + (((.lastMessagePreview // "") | gsub("[\n\r]+"; " "))[0:40])
            )
          | join("\n")
        ) as $bullets
      | (
          "📇 CRM: 連絡候補（能動トリガ）。優先度上位 \($top | length) 件を表示（全 \($n) 件をスコア順）。\n"
          + $bullets
          + (if $rest > 0 then "\n…スコアの低い残り \($rest) 件は省略" else "" end)
          + "\n\n【指示】この候補をユーザーに AskUserQuestion で提示せよ。"
          + "各候補について「下書きを作る / スヌーズ / 却下」を選べるようにし、"
          + "「下書きを作る」は contactId と chatId で下書き→送信レビューに進む(LLM は自動送信しない・必ず人間承認)。"
          + "「スヌーズ」「却下」は crm_dismiss(contactId, trigger, lastActivityAt, action=snooze|dismiss) を呼んで記録する。"
          + "ユーザーが無視したら何もしない。"
        ) as $ctx
      | {hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}
    end
' 2>/dev/null || true)"

[ -z "$OUT" ] && exit 0
printf '%s\n' "$OUT"
exit 0
