#!/usr/bin/env bash
# imsg-history — JSON request -> JSONL read-only iMessage history client.
#
# The client never touches chat.db. A stable signed per-user bridge owns the
# Full Disk Access boundary and accepts one allowlisted request per socket.
set -euo pipefail

readonly SOCK="${IMSG_HISTORY_SOCKET:-$HOME/Library/Application Support/MessageHistoryBridge/message-historyd.sock}"
readonly REMOTE_HOST="${IMSG_HISTORY_HOST:-}"
readonly REQUEST_TIMEOUT="${IMSG_HISTORY_TIMEOUT_SECONDS:-300}"

[[ "$REQUEST_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || {
  printf 'imsg-history: IMSG_HISTORY_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 64
}

usage() {
  cat <<'HELP'
usage:
  imsg-history status
  imsg-history recent [LIMIT]
  imsg-history search QUERY [LIMIT]
  imsg-history with HANDLE [LIMIT]
  imsg-history chat CHAT_GUID [LIMIT]
  imsg-history chats [QUERY] [LIMIT]
  JSON | imsg-history request

stdout is JSONL. Every successful stream ends with:
  {"type":"end","ok":true,"count":N,...}

The bridge is read-only. It does not send messages or open attachments.
HELP
}

limit_json() {
  local value="${1:-20}"
  [[ "$value" =~ ^[0-9]+$ ]] || {
    printf 'imsg-history: limit must be an integer\n' >&2
    exit 64
  }
  printf '%s' "$value"
}

readonly OP="${1:-status}"
shift || true

case "$OP" in
  status)
    request='{"op":"status"}'
    ;;
  recent)
    request="$(jq -cn --argjson limit "$(limit_json "${1:-20}")" \
      '{op:"recent",spec:{limit:$limit}}')"
    ;;
  search)
    [[ $# -ge 1 ]] || { usage >&2; exit 64; }
    request="$(jq -cn --arg query "$1" --argjson limit "$(limit_json "${2:-40}")" \
      '{op:"search",spec:{query:$query,limit:$limit}}')"
    ;;
  with)
    [[ $# -ge 1 ]] || { usage >&2; exit 64; }
    request="$(jq -cn --arg handle "$1" --argjson limit "$(limit_json "${2:-60}")" \
      '{op:"with",spec:{handle:$handle,limit:$limit}}')"
    ;;
  chat)
    [[ $# -ge 1 ]] || { usage >&2; exit 64; }
    request="$(jq -cn --arg chatGUID "$1" --argjson limit "$(limit_json "${2:-60}")" \
      '{op:"chat",spec:{chatGUID:$chatGUID,limit:$limit}}')"
    ;;
  chats)
    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
      request="$(jq -cn --argjson limit "$(limit_json "$1")" \
        '{op:"chats",spec:{limit:$limit}}')"
    elif [[ -n "${1:-}" ]]; then
      request="$(jq -cn --arg query "$1" --argjson limit "$(limit_json "${2:-40}")" \
        '{op:"chats",spec:{query:$query,limit:$limit}}')"
    else
      request='{"op":"chats","spec":{"limit":40}}'
    fi
    ;;
  request)
    request="$(jq -ce 'select(type == "object")' | head -n 1)"
    ;;
  -h | --help | help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

umask 077
response="$(mktemp "${TMPDIR:-/tmp}/imsg-history.XXXXXX")"
trap 'rm -f "$response"' EXIT INT TERM

if [[ -S "$SOCK" ]]; then
  if ! printf '%s\n' "$request" | timeout "$REQUEST_TIMEOUT" nc -U "$SOCK" >"$response"; then
    jq -cn '{type:"end",ok:false,count:0,error:"MessageHistoryBridge transport failed"}' >"$response"
  fi
elif [[ -n "$REMOTE_HOST" ]]; then
  printf -v remote_socket '%q' "$SOCK"
  if ! printf '%s\n' "$request" \
    | timeout "$REQUEST_TIMEOUT" ssh -o ConnectTimeout=8 "$REMOTE_HOST" "nc -U $remote_socket" \
      >"$response"; then
    jq -cn '{type:"end",ok:false,count:0,error:"MessageHistoryBridge remote transport failed"}' >"$response"
  fi
else
  jq -cn '{type:"end",ok:false,count:0,error:"MessageHistoryBridge socket is unavailable"}' >"$response"
fi

if ! jq -e -s 'length > 0 and (last.type == "end")' "$response" >/dev/null 2>&1; then
  jq -cn '{type:"end",ok:false,count:0,error:"MessageHistoryBridge returned an incomplete stream"}' >"$response"
fi

cat "$response"
jq -e -s 'length > 0 and (last.type == "end") and (last.ok == true)' "$response" >/dev/null
