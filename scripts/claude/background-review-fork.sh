#!/bin/bash
# Stop-hook (async): Background review fork.
# Inspired by Hermes' self-improvement loop: after a substantive turn,
# fork a lightweight subagent to analyze the transcript and propose memory updates.
# Proposals are staged to work/pending-memory/ for human review — never written directly.
#
# Loop-safe: one invocation per session_id (marker file).
# Fail-open: any error → exit 0.

set -uo pipefail

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
[[ -z "$SESSION_ID" || -z "$TRANSCRIPT" ]] && exit 0

# One-shot per session: skip if already processed
MARKER_DIR="${TMPDIR:-/tmp}/claude-background-review"
MARKER="$MARKER_DIR/$SESSION_ID"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
[[ -f "$MARKER" ]] && exit 0

# Only process sessions with mutation activity
MUTATIONS=$(grep -c '"tool_use"' "$TRANSCRIPT" 2>/dev/null || echo 0)
[[ "$MUTATIONS" -lt 1 ]] && exit 0

# Extract last assistant turn with tool_use (the mutation context)
LAST_MUTATION=$(grep '"tool_use"' "$TRANSCRIPT" 2>/dev/null | tail -5 | jq -r '
  .message.content[]? | select(.type == "tool_use") |
  "\(.name): \((.input | tostring)[0:300])"
' 2>/dev/null | tail -10)
[[ -z "$LAST_MUTATION" ]] && exit 0

# Stage directory for pending memory proposals
PENDING_DIR="$HOME/Documents/Codex/work/pending-memory"
mkdir -p "$PENDING_DIR" 2>/dev/null || true

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="$PENDING_DIR/${SESSION_ID}-${TIMESTAMP}.md"

# Build analysis prompt
ANALYSIS_PROMPT="You are reviewing the end of a Claude Code session to identify durable lessons worth saving to memory.

Recent tool calls from this session:
$LAST_MUTATION

Based on these actions, identify if there is a generalizable lesson (a gotcha, a workflow pattern, a correction of an incorrect assumption) that should be saved to memory.

If YES: output exactly this format (no preamble):
TARGET: <filename.md or MEMORY.md>
ACTION: append
CONTENT: <one-line pointer text for MEMORY.md index, format: '- key insight→[*](filename.md)'>

If NO durable lesson: output exactly 'NO_LESSON'

Be conservative: only propose when you found something genuinely reusable."

# Run lightweight subagent (read-only analysis, no tools)
RESULT=$(${CLAUDE_BIN:-claude} --print --model claude-haiku-4-5-20250929 \
  --max-turns 1 --no-tools \
  "$ANALYSIS_PROMPT" 2>/dev/null) || true

[[ -z "$RESULT" ]] && exit 0

# Check for meaningful output
if printf '%s' "$RESULT" | grep -q '^NO_LESSON'; then
  touch "$MARKER"
  exit 0
fi

if printf '%s' "$RESULT" | grep -q '^TARGET:'; then
  {
    echo "# Memory proposal from background review"
    echo "session: $SESSION_ID"
    echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "---"
    echo "$RESULT"
  } > "$OUTPUT_FILE"
fi

touch "$MARKER"
exit 0
