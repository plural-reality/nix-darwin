#!/bin/bash
# himalaya CLI wrapper — 非インタラクティブメール操作
# Usage: himalaya-mail.sh <command> [args...]

set -euo pipefail

HIMALAYA="himalaya"

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
