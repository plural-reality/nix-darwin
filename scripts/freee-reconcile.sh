#!/usr/bin/env bash
# freee-reconcile: 口座残高 vs 登録済み仕訳の照合を1コールに畳む。
#
#   stdin  JSON : {"walletable_id":N, "walletable_type"?:"bank_account",
#                  "start_date"?:"YYYY-MM-DD", "end_date"?:"YYYY-MM-DD"}
#   stdout JSON : {walletable_id, walletable_type, range, txn_count,
#                  current_balance, registered_total,
#                  unregistered_count, unregistered_total,
#                  by_status[], unregistered_txns[]}
#
# 事実だけで定義する（推測しない）:
#   - freee の wallet_txns は各明細に `balance`（その時点の口座残高）と
#     `due_amount`（未消込額）を持つ。
#   - 「未登録（未消込）」 ⇔ due_amount > 0。「登録済み」 ⇔ due_amount == 0。
#   - current_balance = (date,id) で最後の明細の balance（=現在残高）。
#
# freee-call を合成して透過層を再利用する（auth/transport を二重に持たない）。
set -euo pipefail

IN=$(cat)
WID=$(jq -r '.walletable_id // empty' <<<"$IN")
WTYPE=$(jq -r '.walletable_type // "bank_account"' <<<"$IN")
START=$(jq -r '.start_date // empty' <<<"$IN")
END=$(jq -r '.end_date // empty' <<<"$IN")

[[ -z "$WID" ]] && { printf '%s\n' '{"ok":false,"error":"walletable_id required on stdin"}' >&2; exit 2; }

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
offset=0
while : ; do
  q=$(jq -nc --arg wt "$WTYPE" --argjson wid "$WID" --argjson off "$offset" \
        --arg s "$START" --arg e "$END" '
        {path:"/api/1/wallet_txns",
         query: ({walletable_type:$wt, walletable_id:$wid, limit:100, offset:$off}
           + (if $s=="" then {} else {start_date:$s} end)
           + (if $e=="" then {} else {end_date:$e} end))}')
  # `|| true`: freee-call exits non-zero on transport failure (missing OAuth,
  # token refresh, network). Under `set -e` that would abort at this assignment
  # before the diagnostic branch below; `page` still captures freee-call's error
  # JSON, so we let it through and surface it explicitly.
  page=$(printf '%s\n' "$q" | freee-call) || true
  if [[ "$(jq 'has("wallet_txns")' <<<"$page" 2>/dev/null)" != "true" ]]; then
    # transport/HTTP error: surface freee's own error object and stop.
    printf '%s\n' "$page" >&2
    exit 1
  fi
  cnt=$(jq -r '.wallet_txns | length' <<<"$page")
  jq -c '.wallet_txns[]' <<<"$page" >> "$tmp"
  if [[ "$cnt" -lt 100 ]]; then break; fi
  offset=$((offset + 100))
done

jq -s --argjson wid "$WID" --arg wt "$WTYPE" --arg s "$START" --arg e "$END" '
  {
    walletable_id: $wid,
    walletable_type: $wt,
    range: {start: (if $s=="" then null else $s end), end: (if $e=="" then null else $e end)},
    txn_count: length,
    current_balance: (if length>0 then (sort_by(.date, .id) | last | .balance) else null end),
    registered_total: (map(select(.due_amount==0) | .amount) | add // 0),
    unregistered_count: (map(select(.due_amount>0)) | length),
    unregistered_total: (map(select(.due_amount>0) | .due_amount) | add // 0),
    by_status: (group_by(.status)
      | map({status:.[0].status, count:length,
             amount:(map(.amount)|add // 0),
             due_total:(map(.due_amount)|add // 0)})),
    unregistered_txns: (map(select(.due_amount>0)
      | {id, date, amount, due_amount, entry_side, description}))
  }' "$tmp"
