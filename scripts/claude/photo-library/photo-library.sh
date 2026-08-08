#!/usr/bin/env bash
# photo-library — typed JSON/JSONL client for the signed read-only Photos bridge.
set -euo pipefail

readonly SOCK="${PHOTO_LIBRARY_SOCKET:-$HOME/Library/Application Support/PhotoLibraryBridge/photo-libraryd.sock}"
readonly REQUEST_TIMEOUT="${PHOTO_LIBRARY_TIMEOUT_SECONDS:-600}"
readonly APP="${PHOTO_LIBRARY_APP:-$HOME/Library/Application Support/PhotoLibraryBridge/current}"

usage() {
  cat <<'HELP'
usage:
  photo-library status
  photo-library authorize
  photo-library snapshot
  JSON | photo-library request

stdout is JSONL. The bridge can read/classify/export images but cannot edit or
delete Photos assets. classify/export are available through the typed request.
HELP
}

readonly OP="${1:-status}"
case "$OP" in
  status) request='{"op":"status"}' ;;
  authorize)
    [[ -d "$APP" ]] || {
      jq -cn '{type:"end",ok:false,count:0,error:"PhotoLibraryBridge app is unavailable"}'
      exit 1
    }
    resolved_app="$(realpath "$APP")"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -f "$resolved_app"
    open -gn "$resolved_app" --args --authorize-ui
    jq -cn '{type:"authorization_prompt",opened:true}'
    jq -cn '{type:"end",ok:true,count:1}'
    exit 0
    ;;
  snapshot) request='{"op":"snapshot"}' ;;
  request) request="$(jq -ce 'select(type == "object")' | head -n 1)" ;;
  -h | --help | help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

[[ "$REQUEST_TIMEOUT" =~ ^[1-9][0-9]*$ ]] || {
  printf 'photo-library: PHOTO_LIBRARY_TIMEOUT_SECONDS must be a positive integer\n' >&2
  exit 64
}

umask 077
response="$(mktemp "${TMPDIR:-/tmp}/photo-library.XXXXXX")"
trap 'rm -f "$response"' EXIT INT TERM

if [[ -S "$SOCK" ]]; then
  printf '%s\n' "$request" | timeout "$REQUEST_TIMEOUT" nc -U "$SOCK" >"$response" || \
    jq -cn '{type:"end",ok:false,count:0,error:"PhotoLibraryBridge transport failed"}' >"$response"
else
  jq -cn '{type:"end",ok:false,count:0,error:"PhotoLibraryBridge socket is unavailable"}' >"$response"
fi

jq -e -s 'length > 0 and (last.type == "end")' "$response" >/dev/null 2>&1 || \
  jq -cn '{type:"end",ok:false,count:0,error:"PhotoLibraryBridge returned an incomplete stream"}' >"$response"

cat "$response"
jq -e -s 'length > 0 and (last.type == "end") and (last.ok == true)' "$response" >/dev/null
