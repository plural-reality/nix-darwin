scratch="$(mktemp -d "${TMPDIR:-/tmp}/test-fable-consult.XXXXXX")"
trap 'command rm -rf -- "$scratch"' EXIT

cat >"$scratch/timeout" <<'FAKE_TIMEOUT'
#!/usr/bin/env bash
set -euo pipefail
while [[ "$1" == --* ]]; do shift; done
shift # duration
if [[ "${FABLE_TEST_MODE:-}" == timeout ]]; then
  "$@" &
  pid="$!"
  sleep 0.1
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  exit 124
fi
exec "$@"
FAKE_TIMEOUT
chmod +x "$scratch/timeout"

cat >"$scratch/claude" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null
count="$(cat "$FABLE_TEST_STATE" 2>/dev/null || printf 0)"
next="$((count + 1))"
printf '%s\n' "$next" >"$FABLE_TEST_STATE"

case "${FABLE_TEST_MODE:-retry}" in
  retry)
    [[ "$next" -eq 1 ]] \
      && printf '%s\n' '{"is_error":false,"subtype":"success","terminal_reason":"completed","stop_reason":"end_turn","result":"  \n"}' \
      || printf '%s\n' '{"is_error":false,"subtype":"success","terminal_reason":"completed","stop_reason":"end_turn","result":"RETRY_OK"}'
    ;;
  fail)
    printf '%s\n' '{"is_error":false,"subtype":"success","terminal_reason":"completed","stop_reason":"end_turn","result":""}'
    ;;
  timeout)
    sleep 2
    printf '%s\n' '{"is_error":false,"subtype":"success","terminal_reason":"completed","stop_reason":"end_turn","result":"UNREACHABLE"}'
    ;;
esac
FAKE
chmod +x "$scratch/claude"

state="$scratch/state"
PATH="$scratch:$PATH" FABLE_TEST_STATE="$state" \
  bash "$(dirname "$0")/fable-consult.sh" <<'EOF' \
  >"$scratch/stdout" 2>"$scratch/stderr"
# Decision
Harmless retry test.
EOF

diff -u <(printf 'RETRY_OK\n') "$scratch/stdout"
grep -q 'retrying once' "$scratch/stderr"
[[ "$(cat "$state")" == 2 ]]

printf 0 >"$state"
set +e
PATH="$scratch:$PATH" FABLE_TEST_STATE="$state" FABLE_TEST_MODE=fail \
  bash "$(dirname "$0")/fable-consult.sh" <<'EOF' \
  >"$scratch/fail.stdout" 2>"$scratch/fail.stderr"
# Decision
Harmless failure test.
EOF
failure_status=$?
set -e

[[ "$failure_status" -eq 70 ]]
[[ ! -s "$scratch/fail.stdout" ]]
grep -q 'failed after two attempts' "$scratch/fail.stderr"
grep -q 'result_bytes=0' "$scratch/fail.stderr"
[[ "$(cat "$state")" == 2 ]]

printf 0 >"$state"
set +e
PATH="$scratch:$PATH" FABLE_TEST_STATE="$state" FABLE_TEST_MODE=timeout FABLE_TIMEOUT_SECONDS=1 \
  bash "$(dirname "$0")/fable-consult.sh" <<'EOF' \
  >"$scratch/timeout.stdout" 2>"$scratch/timeout.stderr"
# Decision
Timeout retry test.
EOF
timeout_status=$?
set -e

[[ "$timeout_status" -eq 70 ]]
[[ ! -s "$scratch/timeout.stdout" ]]
grep -q 'failed after two attempts' "$scratch/timeout.stderr"
grep -q 'exit=124' "$scratch/timeout.stderr"
[[ "$(cat "$state")" == 2 ]]

printf '%s\n' 'fable-consult retry contract: OK'
