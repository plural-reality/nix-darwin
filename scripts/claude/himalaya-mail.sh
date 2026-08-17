#!/bin/bash
# himalaya CLI wrapper — 非インタラクティブメール操作
# Usage: himalaya-mail.sh <command> [args...]

set -euo pipefail

HIMALAYA="himalaya"

# Himalaya 1.x moved its macOS default under Application Support. Preserve a
# migrated account without copying credentials: resolve the newest local
# premigration file only when neither an injected nor canonical config exists.
canonical_himalaya_config="$HOME/Library/Application Support/himalaya/config.toml"
legacy_himalaya_config=$(find "$(dirname "$canonical_himalaya_config")" -maxdepth 1 \
  -type f -name 'config.toml.premigrate-*' -print 2>/dev/null | sort | tail -n 1)
[[ -n "${HIMALAYA_CONFIG:-}" || -f "$canonical_himalaya_config" || -z "$legacy_himalaya_config" ]] || \
  export HIMALAYA_CONFIG="$legacy_himalaya_config"

# デフォルトアカウント
DEFAULT_ACCOUNT="gmail"

usage() {
  cat <<'EOF'
himalaya-mail.sh — himalaya CLI wrapper

Commands:
  accounts                              List configured accounts
  folders [account]                     List folders
  inbox [account] [page-size]           List inbox envelopes
  read <id> [account]                   Read a message
  search <query> [account] [page-size]  Search messages (page-size default 40)
  style <recipient> [account] [limit]   Show CRM rules + actual sent examples
  send <to> <subject> <body> [account]  Send a new message
  reply <id> <body> [account]           Reply to sender only
  reply-all <id> <body> [account]       Reply to all (To + CC)
  forward <id> <to> [body] [account]    Forward a message
EOF
}

# アカウントフラグ生成
account_flag() {
  local acct="${1:-$DEFAULT_ACCOUNT}"
  echo "-a" "$acct"
}

case "${1:-help}" in
  accounts)
    $HIMALAYA account list
    ;;

  folders)
    $HIMALAYA folder list $(account_flag "${2:-}")
    ;;

  inbox)
    local_account="${2:-$DEFAULT_ACCOUNT}"
    local_page_size="${3:-20}"
    $HIMALAYA envelope list -a "$local_account" -s "$local_page_size"
    ;;

  read)
    local_id="${2:?Usage: himalaya-mail.sh read <id> [account]}"
    local_account="${3:-$DEFAULT_ACCOUNT}"
    $HIMALAYA message read -a "$local_account" "$local_id"
    ;;

  search)
    # query は himalaya の positional args として渡す。
    # field 必須: "from google", "body サロモン", "subject 会議", "after 2026-03-01"。
    # 日本語の素キーワードは不可 (body/subject を付ける)。複雑な or は単一 field で叩き直す。
    local_query="${2:?Usage: himalaya-mail.sh search <query> [account] [page-size]}"
    local_account="${3:-$DEFAULT_ACCOUNT}"
    local_page_size="${4:-40}"
    # shellcheck disable=SC2086
    $HIMALAYA envelope list -a "$local_account" -s "$local_page_size" $local_query
    ;;

  style)
    local_recipient="${2:?Usage: himalaya-mail.sh style <recipient> [account] [limit]}"
    local_account="${3:-$DEFAULT_ACCOUNT}"
    local_limit="${4:-3}"
    local_beeper_style="$HOME/.claude/skills/beeper-send/scripts/beeper-send.sh"

    echo "# CRM人物別文体"
    set +e
    crm_style_output=$("$local_beeper_style" style "$local_recipient" 2>&1)
    crm_style_status=$?
    set -e
    case "$crm_style_status" in
      0) printf '%s\n' "$crm_style_output" ;;
      44) echo "(CRM連絡先に一致なし。人物別ルールなし)" ;;
      *) printf '%s\n' "$crm_style_output" >&2; exit "$crm_style_status" ;;
    esac

    sent_folder=$($HIMALAYA folder list -a "$local_account" -o json --quiet | \
      python3 -c '
import json, sys
names = [(item.get("name", "") if isinstance(item, dict) else str(item)) for item in json.load(sys.stdin)]
matches = [name for name in names if "送信済み" in name or "sent" in name.casefold()]
print(matches[0] if matches else "")
')
    [[ -n "$sent_folder" ]] || { echo "ERROR: sent folder not found" >&2; exit 1; }

    envelopes=$($HIMALAYA envelope list -a "$local_account" -f "$sent_folder" \
      -s 40 -o json --quiet to "$local_recipient" order by date desc)
    ids=$(MAIL_ENVELOPES="$envelopes" MAIL_LIMIT="$local_limit" python3 -c '
import json, os
items = json.loads(os.environ["MAIL_ENVELOPES"])
print(" ".join(str(item["id"]) for item in items[:int(os.environ["MAIL_LIMIT"])]))
')

    echo "# 本人がこの宛先へ実際に送ったメール例"
    [[ -n "$ids" ]] || { echo "(送信済みメールに一致なし)"; exit 0; }
    example_index=0
    for message_id in $ids; do
      example_index=$((example_index + 1))
      echo "## 例${example_index}"
      $HIMALAYA message read -a "$local_account" -f "$sent_folder" --preview \
        --no-headers --quiet "$message_id" | python3 -c '
import re, sys
lines = sys.stdin.read().splitlines()
cut = next((i for i, line in enumerate(lines) if re.match(r"^(On .+wrote:|-{2,}\s*Original Message\s*-{2,}|.+<.+@.+>[:：])$", line.strip(), re.I)), len(lines))
body = "\n".join(line for line in lines[:cut] if not line.lstrip().startswith(">"))
print(body.strip()[:2400])
'
    done
    ;;

  send)
    local_to="${2:?Usage: himalaya-mail.sh send <to> <subject> <body> [account]}"
    local_subject="${3:?Usage: himalaya-mail.sh send <to> <subject> <body> [account]}"
    local_body="${4:?Usage: himalaya-mail.sh send <to> <subject> <body> [account]}"
    local_account="${5:-$DEFAULT_ACCOUNT}"

    tmpfile=$(mktemp /tmp/himalaya-send.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    cat > "$tmpfile" <<EOMAIL
From: $(himalaya account list -a "$local_account" 2>/dev/null | grep -o '[^ ]*@[^ ]*' | head -1)
To: ${local_to}
Subject: ${local_subject}

${local_body}
EOMAIL

    $HIMALAYA template send -a "$local_account" < "$tmpfile"
    echo "OK: Message sent to ${local_to}"
    ;;

  reply)
    local_id="${2:?Usage: himalaya-mail.sh reply <id> <body> [account]}"
    local_body="${3:?Usage: himalaya-mail.sh reply <id> <body> [account]}"
    local_account="${4:-$DEFAULT_ACCOUNT}"

    tmpfile=$(mktemp /tmp/himalaya-reply.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    # 返信テンプレートを取得して、ヘッダー後の最初の空行の後に本文を差し込む
    $HIMALAYA template reply -a "$local_account" "$local_id" | \
      python3 -c "
import sys
body = sys.argv[1]
lines = sys.stdin.read().split('\n')
found_blank = False
for i, line in enumerate(lines):
    print(line)
    if not found_blank and line == '' and i > 0:
        print(body)
        found_blank = True
" "$local_body" > "$tmpfile"

    $HIMALAYA template send -a "$local_account" < "$tmpfile"
    echo "OK: Reply sent (to sender only)"
    ;;

  reply-all)
    local_id="${2:?Usage: himalaya-mail.sh reply-all <id> <body> [account]}"
    local_body="${3:?Usage: himalaya-mail.sh reply-all <id> <body> [account]}"
    local_account="${4:-$DEFAULT_ACCOUNT}"

    tmpfile=$(mktemp /tmp/himalaya-reply-all.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    # --all で全員返信テンプレート取得 (To + CC を自動保持、In-Reply-To/References 自動付与)
    $HIMALAYA template reply --all -a "$local_account" "$local_id" | \
      python3 -c "
import sys
body = sys.argv[1]
lines = sys.stdin.read().split('\n')
found_blank = False
for i, line in enumerate(lines):
    print(line)
    if not found_blank and line == '' and i > 0:
        print(body)
        found_blank = True
" "$local_body" > "$tmpfile"

    $HIMALAYA template send -a "$local_account" < "$tmpfile"
    echo "OK: Reply-all sent (To + CC)"
    ;;

  forward)
    local_id="${2:?Usage: himalaya-mail.sh forward <id> <to> [body] [account]}"
    local_to="${3:?Usage: himalaya-mail.sh forward <id> <to> [body] [account]}"
    local_body="${4:-}"
    local_account="${5:-$DEFAULT_ACCOUNT}"

    tmpfile=$(mktemp /tmp/himalaya-forward.XXXXXX)
    trap 'rm -f "$tmpfile"' EXIT

    # 転送テンプレートを取得してTo:を書き換え、本文を追加
    $HIMALAYA template forward -a "$local_account" "$local_id" | \
      python3 -c "
import sys
to_addr = sys.argv[1]
body = sys.argv[2] if len(sys.argv) > 2 else ''
lines = sys.stdin.read().split('\n')
found_blank = False
for i, line in enumerate(lines):
    if line.startswith('To:'):
        print(f'To: {to_addr}')
    else:
        print(line)
    if not found_blank and line == '' and i > 0:
        if body:
            print(body)
        found_blank = True
" "$local_to" "$local_body" > "$tmpfile"

    $HIMALAYA template send -a "$local_account" < "$tmpfile"
    echo "OK: Forwarded to ${local_to}"
    ;;

  help|*)
    usage
    ;;
esac
