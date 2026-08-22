#!/bin/bash
# Staged memory write approval gate.
# Lists, diffs, and applies (or rejects) pending memory proposals.
# Usage: staged-memory-write.sh [list|show|approve|reject] [file]

set -euo pipefail

readonly PENDING_DIR="$HOME/Documents/Codex/work/pending-memory"
readonly MEMORY_DIR="$HOME/.claude/projects/-Users-tkgshn/memory"

cmd="${1:-list}"

case "$cmd" in
  list)
    if [[ ! -d "$PENDING_DIR" ]] || ! ls "$PENDING_DIR"/*.md >/dev/null 2>&1; then
      echo "No pending proposals."
      exit 0
    fi
    echo "Pending memory proposals:"
    for f in "$PENDING_DIR"/*.md; do
      session=$(grep '^session:' "$f" 2>/dev/null | head -1 | cut -d' ' -f2-)
      date=$(grep '^date:' "$f" 2>/dev/null | head -1 | cut -d' ' -f2-)
      target=$(grep '^TARGET:' "$f" 2>/dev/null | head -1 | sed 's/^TARGET: //')
      echo "  $(basename "$f")  target=${target:-?}  session=${session:0:8}  $date"
    done
    ;;
  show)
    file="${2:?Usage: staged-memory-write.sh show <file>}"
    cat "$PENDING_DIR/$file"
    ;;
  approve)
    file="${2:?Usage: staged-memory-write.sh approve <file>}"
    filepath="$PENDING_DIR/$file"
    [[ -f "$filepath" ]] || { echo "Not found: $filepath"; exit 1; }

    target=$(grep '^TARGET:' "$filepath" | head -1 | sed 's/^TARGET: //' | tr -d '[:space:]')
    content=$(sed -n '/^CONTENT: /,$ p' "$filepath" | sed '1s/^CONTENT: //')
    pointer=$(echo "$content" | grep -oP '\[.*?\]\(.*?\)' | tail -1)
    
    [[ -z "$target" || -z "$content" ]] && { echo "Malformed proposal."; exit 1; }

    dest="$MEMORY_DIR/$target"
    
    # Show what will be done
    if [[ -f "$dest" ]]; then
      echo "--- Existing content ---"
      cat "$dest"
      echo "--- Proposed append ---"
      echo "$content"
    else
      echo "--- New file: $dest ---"
      echo "$content"
    fi

    printf "Apply? [y/N] "
    read -r answer
    [[ "$answer" != "y" && "$answer" != "Y" ]] && { echo "Rejected (not deleted). Run reject to clean up."; exit 0; }

    mkdir -p "$(dirname "$dest")"
    if [[ -f "$dest" ]]; then
      printf '\n%s\n' "$content" >> "$dest"
    else
      echo "$content" > "$dest"
    fi

    # Add pointer to MEMORY.md if not already present
    if [[ -n "$pointer" && -f "$MEMORY_DIR/MEMORY.md" ]] && ! grep -qF "$pointer" "$MEMORY_DIR/MEMORY.md"; then
      echo "- $pointer" >> "$MEMORY_DIR/MEMORY.md"
    fi

    rm -f "$filepath"
    echo "Applied and cleaned up: $target"
    ;;
  reject)
    file="${2:?Usage: staged-memory-write.sh reject <file>}"
    rm -f "$PENDING_DIR/$file"
    echo "Deleted: $file"
    ;;
  *)
    echo "Usage: staged-memory-write.sh [list|show|approve|reject] [file]"
    exit 1
    ;;
esac
