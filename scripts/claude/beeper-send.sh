#!/bin/bash
set -euo pipefail

# Compatibility entrypoint only. The implementation lives with the shared
# skill so Claude and Codex cannot silently acquire different send semantics.
exec "$HOME/.claude/skills/beeper-send/scripts/beeper-send.sh" "$@"
