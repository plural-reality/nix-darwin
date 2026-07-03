#!/usr/bin/env bash
# Self-check:
#   printf '{"cwd":"/tmp/not-a-repo","session_id":"0123456789"}' | bash scripts/claude/journal-checkpoint.sh
#   # exits 0 and writes nothing outside an allowlisted journal/* git repo.
set -euo pipefail

ALLOWLIST_REPOS=("beeper-scrapbox-crm")

json_get() {
  local key="$1"
  python3 -c 'import json, sys; data=json.load(sys.stdin); print(data.get(sys.argv[1], ""))' "$key"
}

contains_repo() {
  local repo="$1"
  local allowed
  for allowed in "${ALLOWLIST_REPOS[@]}"; do
    [[ "$repo" == "$allowed" ]] && return 0
  done
  return 1
}

main() {
  local payload cwd root repo branch dirty_count session_id sid ts
  payload="$(cat)"
  cwd="$(printf '%s' "$payload" | json_get cwd)"
  session_id="$(printf '%s' "$payload" | json_get session_id)"

  [[ -n "$cwd" && -d "$cwd" ]] || return 0
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$root" ]] || return 0

  repo="$(basename "$root")"
  contains_repo "$repo" || return 0

  branch="$(git -C "$root" branch --show-current 2>/dev/null || true)"
  [[ "$branch" == journal/* ]] || return 0

  [[ -n "$(git -C "$root" status --porcelain)" ]] || return 0
  dirty_count="$(git -C "$root" status --porcelain | wc -l | tr -d '[:space:]')"
  sid="${session_id:0:8}"
  [[ -n "$sid" ]] || sid="unknown"
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  git -C "$root" add -A
  git -C "$root" commit -m "cp: $sid $ts [${dirty_count}f]"
}

main "$@" >/dev/null 2>&1 || true
