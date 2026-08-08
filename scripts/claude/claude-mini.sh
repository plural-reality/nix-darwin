#!/usr/bin/env bash
# Interactive sessions live on the Mac mini. One-shot/control-plane commands
# must stay on the Air: they operate on this machine's config and OAuth callback.
case "${1-}" in
  mcp | --version | -v | --help | -h | -p | --print)
    exec claude "$@"
    ;;
  *)
    exec "$(dirname "$0")/run-on-mini.sh" cc claude "$@"
    ;;
esac
