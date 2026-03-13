# claude-history: Fast cross-project Claude Code session search via fzf
# Architecture: Filter Pattern — JSONL → cached index → fzf → resume command
# Dependencies injected by Nix: fzf, jq, coreutils (GNU), gnused
# NOTE: Uses GNU coreutils/sed syntax (stat -c, sed -i without '') since
# writeShellApplication injects these via runtimeInputs

readonly CLAUDE_DIR="${HOME}/.claude"
readonly PROJECTS_DIR="${CLAUDE_DIR}/projects"
readonly INDEX_FILE="${CLAUDE_DIR}/.history-index.tsv"
readonly LOCK_FILE="${CLAUDE_DIR}/.history-index.lock"

# --- Index building ---

build_index_for_file() {
  local jsonl_file="$1"
  local session_id
  session_id="$(basename "$jsonl_file" .jsonl)"

  # Skip agent/subagent sessions (they're internal)
  [[ "$session_id" == agent-* ]] && return 0

  # Extract project name from directory
  local project_dir
  project_dir="$(basename "$(dirname "$jsonl_file")")"
  local project
  project="$(echo "$project_dir" | sed 's/^-Users-[^-]*-*//' | sed 's/-/\//g')"
  [ -z "$project" ] && project="~"
  # Shorten common prefixes
  project="$(echo "$project" | sed 's|^Developer/plural/reality/||' | sed 's|^Developer/||')"

  # Extract timestamp and first meaningful user message
  # Use head -100 to avoid reading massive files entirely
  local result
  result="$(head -100 "$jsonl_file" | jq -r '
    select(.type == "user") |
    {
      ts: .timestamp,
      msg: (
        .message |
        (fromjson? // .) |
        (if (.content | type) == "string" then .content
         elif (.content | type) == "array" then
           ([.content[] | select(.type == "text") | .text] | join(" "))
         else "" end) |
        gsub("[\\n\\r\\t]+"; " ") |
        gsub("<[^>]*>"; "") |
        gsub("^ +| +$"; "") |
        gsub("```[^`]*```"; "[code]")
      )
    } |
    select(
      .msg != "" and
      (.msg | length) > 10 and
      (.msg | test("^Caveat: The messages") | not) and
      (.msg | test("clear$") | not) and
      (.msg | test("^/clear") | not) and
      (.msg | test("^command-") | not) and
      (.msg | test("^fast$") | not)
    ) |
    "\(.ts)\t\(.msg | .[0:200])"
  ' 2>/dev/null | head -1)"

  [ -z "$result" ] && return 0

  local ts msg
  ts="$(echo "$result" | cut -f1)"
  msg="$(echo "$result" | cut -f2-)"

  # Format date for display (GNU date via Nix runtimeInputs)
  local date_str
  date_str="$(date -d "${ts%%.*}" "+%m/%d %H:%M" 2>/dev/null || echo "${ts:0:16}")"

  printf '%s\t%s\t%s\t%s\n' "$session_id" "$date_str" "$project" "$msg"
}

rebuild_index() {
  local force="${1:-false}"

  # Simple file-level lock
  if [ -f "$LOCK_FILE" ]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
    [ "$lock_age" -lt 60 ] && { echo "Index build in progress..." >&2; return 1; }
    rm -f "$LOCK_FILE"
  fi
  touch "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT

  local tmp_index
  tmp_index="$(mktemp)"

  if [ "$force" = "true" ] || [ ! -f "$INDEX_FILE" ]; then
    echo "Building full index..." >&2
    local count=0
    local total
    total="$(find "$PROJECTS_DIR" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')"

    # Use xargs for parallel processing if available
    if command -v xargs >/dev/null 2>&1; then
      export -f build_index_for_file
      find "$PROJECTS_DIR" -name "*.jsonl" -print0 2>/dev/null | \
        xargs -0 -P 8 -I{} bash -c 'build_index_for_file "$@"' _ {} >> "$tmp_index" 2>/dev/null
      echo "  Indexed $total files" >&2
    else
      find "$PROJECTS_DIR" -name "*.jsonl" -print0 2>/dev/null | while IFS= read -r -d '' f; do
        count=$((count + 1))
        printf '\r  [%d/%d]' "$count" "$total" >&2
        build_index_for_file "$f" >> "$tmp_index"
      done
      echo "" >&2
    fi
  else
    # Incremental: only process files newer than index
    cp "$INDEX_FILE" "$tmp_index"
    local new_files
    new_files="$(find "$PROJECTS_DIR" -name "*.jsonl" -newer "$INDEX_FILE" 2>/dev/null || true)"

    if [ -z "$new_files" ]; then
      rm -f "$tmp_index"
      echo "Index is up to date." >&2
      return 0
    fi

    local total
    total="$(echo "$new_files" | wc -l | tr -d ' ')"
    echo "Updating index ($total new sessions)..." >&2

    echo "$new_files" | while read -r f; do
      local sid
      sid="$(basename "$f" .jsonl)"
      # Remove existing entry for this session
      sed -i "/^${sid}	/d" "$tmp_index" 2>/dev/null || true
      build_index_for_file "$f" >> "$tmp_index"
    done
  fi

  # Sort by date descending (field 2)
  sort -t$'\t' -k2 -r "$tmp_index" > "$INDEX_FILE"
  rm -f "$tmp_index"

  local total_entries
  total_entries="$(wc -l < "$INDEX_FILE" | tr -d ' ')"
  echo "Index ready: $total_entries sessions" >&2
}

# --- Search ---

search_sessions() {
  local query="${1:-}"

  # Always run incremental update (only processes new files, fast)
  if [ ! -f "$INDEX_FILE" ]; then
    rebuild_index true
  else
    rebuild_index false
  fi

  [ ! -f "$INDEX_FILE" ] && { echo "No index available." >&2; exit 1; }

  # fzf selection
  local selected
  selected="$(awk -F'\t' '{printf "%s\t%-12s\t%-25s\t%s\n", $1, $2, $3, $4}' "$INDEX_FILE" | \
    fzf \
      --with-nth=2.. \
      --delimiter='\t' \
      --header=$'  Date         Project                   First Message' \
      --query="$query" \
      --prompt='ch> ' \
      --height=80% \
      --reverse \
      --no-sort \
      --ansi \
      --bind="ctrl-r:reload(bash $0 --list | awk -F'\t' '{printf \"%s\t%-12s\t%-25s\t%s\\n\", \$1, \$2, \$3, \$4}')" \
    || true)"

  [ -z "$selected" ] && exit 0

  local session_id
  session_id="$(echo "$selected" | cut -f1)"

  echo ""
  echo "  claude --resume $session_id"
  echo "  claude --resume $session_id --dangerously-skip-permissions"
  echo ""

  # Copy basic resume command to clipboard
  printf "claude --resume %s" "$session_id" | pbcopy
  echo "(copied to clipboard)"
}

# --- Main ---

case "${1:-}" in
  --rebuild)
    rebuild_index true
    ;;
  --list)
    [ ! -f "$INDEX_FILE" ] && rebuild_index true
    cat "$INDEX_FILE"
    ;;
  --help|-h)
    echo "Usage: ch [query]        Interactive fuzzy search"
    echo "       ch --rebuild      Force rebuild index"
    echo "       ch --list         Print index (pipe-friendly)"
    echo "       ch --help         Show help"
    echo ""
    echo "Keys: Ctrl-R to refresh index"
    ;;
  *)
    search_sessions "${1:-}"
    ;;
esac
