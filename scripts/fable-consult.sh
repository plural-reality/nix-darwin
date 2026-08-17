[[ $# -eq 0 ]] || {
  printf '%s\n' 'Usage: fable-consult < brief.md' >&2
  exit 64
}

brief="$(cat)"
[[ -n "${brief//[[:space:]]/}" ]] || {
  printf '%s\n' 'fable-consult: stdin brief is empty' >&2
  exit 64
}

timeout_seconds="${FABLE_TIMEOUT_SECONDS:-900}"
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || {
  printf '%s\n' 'fable-consult: FABLE_TIMEOUT_SECONDS must be a positive integer' >&2
  exit 64
}

scratch="$(mktemp -d "${TMPDIR:-/tmp}/fable-consult.XXXXXX")"
trap 'command rm -rf -- "$scratch"' EXIT

invoke() {
  local label="$1"
  local exit_code=0

  printf '%s' "$brief" \
    | timeout \
      --signal=TERM \
      --kill-after=10s \
      "${timeout_seconds}s" \
      claude \
      --print \
      --safe-mode \
      --model fable \
      --effort max \
      --permission-mode plan \
      --no-session-persistence \
      --output-format json \
      --tools "Read,Glob,Grep" \
      >"$scratch/$label.json" \
      2>"$scratch/$label.stderr" \
    || exit_code=$?

  printf '%s\n' "$exit_code" >"$scratch/$label.status"
}

emit_result() {
  local label="$1"

  [[ "$(cat "$scratch/$label.status")" == 0 ]] \
    || return 1
  jq -er '
    select(.is_error == false)
    | .result
    | strings
    | select(test("\\S"))
  ' "$scratch/$label.json" 2>/dev/null
}

diagnose() {
  local label="$1"
  local status_file="$scratch/$label.status"
  local json_file="$scratch/$label.json"
  local stderr_file="$scratch/$label.stderr"
  local exit_code
  local stderr_excerpt

  exit_code="$(cat "$status_file")"
  jq -er --arg exit_code "$exit_code" '
    select(type == "object")
    | "exit=\($exit_code) subtype=\(.subtype // "unknown") "
      + "terminal_reason=\(.terminal_reason // "unknown") "
      + "stop_reason=\(.stop_reason // "unknown") "
      + "api_error_status=\(.api_error_status // "none") "
      + "result_bytes=\((.result // "") | tostring | utf8bytelength)"
  ' "$json_file" 2>/dev/null && return 0

  stderr_excerpt="$(head -c 500 "$stderr_file" | tr '\n' ' ')"
  printf 'exit=%s invalid_or_empty_json stderr=%s\n' \
    "$exit_code" "${stderr_excerpt:-none}"
}

invoke first
emit_result first && exit 0

printf '%s\n' 'fable-consult: first attempt returned no usable response; retrying once' >&2
invoke retry
emit_result retry && exit 0

printf 'fable-consult: failed after two attempts; first={%s}; retry={%s}\n' \
  "$(diagnose first)" "$(diagnose retry)" >&2
exit 70
