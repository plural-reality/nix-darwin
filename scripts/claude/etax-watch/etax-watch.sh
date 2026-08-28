#!/usr/bin/env bash
# Fixed-interface client for the signed e-Tax read-only broker.
set -euo pipefail

readonly BROKER="$HOME/Library/Application Support/ETaxWatchBridge/current/Contents/MacOS/etax-watchd"
readonly COMMAND="${1:-watch}"

case "$COMMAND" in
  status|enroll|watch)
    [[ $# -le 1 ]] || {
      printf 'usage: etax-watch [status|enroll|watch]\n' >&2
      exit 64
    }
    ;;
  *)
    printf 'usage: etax-watch [status|enroll|watch]\n' >&2
    exit 64
    ;;
esac

[[ -x "$BROKER" ]] || {
  printf '{"ok":false,"status":"認証が必要","error":{"code":"broker_not_installed","message":"e-Tax読取専用brokerが未配置です。","status":"認証が必要"}}\n'
  exit 69
}

exec "$BROKER" "$COMMAND"
