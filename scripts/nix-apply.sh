#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
nix-apply [--mini] [--host HOST]

Apply /etc/nix-darwin locally, or delegate the same apply to a remote host in a
persistent tmux session.

Options:
  --mini         Apply on mac-mini.
  --host HOST   Apply on an explicit SSH host.
  -h, --help    Show this help.
USAGE
}

host=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mini)
      host="mac-mini"
      shift
      ;;
    --host)
      host="${2:?--host requires a host}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'nix-apply: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

flake_dir="${NIX_DARWIN_FLAKE:-/etc/nix-darwin}"

if [[ -n "$host" ]]; then
  remote="cd /etc/nix-darwin && ./apply; exec fish -l"
  exec ssh -t "$host" \
    "tmux new-session -A -s nix-apply -c /etc/nix-darwin $(printf '%q' "$remote")"
fi

cd "$flake_dir"
exec nix run .#apply
