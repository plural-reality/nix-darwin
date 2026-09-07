#!/usr/bin/env bash
# One-way host-local projection; explicit canary allowlist and one writer per host.
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$S/sync_codex.py" "$@"
