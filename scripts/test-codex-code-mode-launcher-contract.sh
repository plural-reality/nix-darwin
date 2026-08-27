#!/usr/bin/env bash
set -euo pipefail

test "$#" -eq 1 || {
  printf '%s\n' 'usage: test-codex-code-mode-launcher-contract.sh <home-files-root>' >&2
  exit 64
}

readonly home_files="$1"
readonly codex_target="$(readlink -f "$home_files/.local/bin/codex")"
readonly code_mode_host_target="$(readlink -f "$home_files/.local/bin/codex-code-mode-host")"

test -x "$codex_target"
test -x "$code_mode_host_target"
printf '%s\n' "$codex_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex$'
printf '%s\n' "$code_mode_host_target" | grep -Eq '^/nix/store/[^/]+-codex-[^/]+/bin/codex-code-mode-host$'

printf '%s\n' 'codex-code-mode-launcher-contract: ok'
