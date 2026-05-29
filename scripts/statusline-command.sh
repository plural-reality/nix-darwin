#!/usr/bin/env bash
# statusline-command.sh
# Stream in (Claude Code statusLine JSON on stdin) -> one status line out.
#
# Layout:
#   <cwd> (branch)  #<session-hash>
#    ctx:N%  5h ▕████░░░░░░▏ N% ↻Hh MMm  [model]
#
# 5h segment is the rolling 5-hour usage limit, taken straight from the
# canonical source Claude Code already hands us: .rate_limits.five_hour
# (used_percentage + resets_at epoch). No external tooling, no caching layer.

input=$(cat)

# Single jq pass: pull every value, joined by Unit Separator (\x1f). A
# non-whitespace delimiter is required so `read` preserves empty fields
# (tab/space/newline are IFS-whitespace and would collapse, mis-aligning
# the record when e.g. rate_limits is absent).
us=$'\x1f'
IFS="$us" read -r cwd model used_pct five_pct resets_at session_id < <(
  jq -r --arg us "$us" '[
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // ""),
    ((.context_window.used_percentage // "") | tostring),
    ((.rate_limits.five_hour.used_percentage // "") | tostring),
    ((.rate_limits.five_hour.resets_at // "") | tostring),
    (.session_id // "")
  ] | join($us)' <<<"$input"
)

display_dir="${cwd/#$HOME/~}"

# Git branch — skip optional locks to avoid contention with Claude's own git ops
git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
  || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" describe --tags --exact-match HEAD 2>/dev/null \
  || echo "")
branch_part=$([ -n "$git_branch" ] && printf " \033[34m(%s)\033[0m" "$git_branch" || echo "")

# Session hash — first 8 hex of the (UUID) session_id, git-short-sha style.
hash_part=$([ -n "$session_id" ] && printf "  \033[2m#%s\033[0m" "${session_id:0:8}" || echo "")

# Context usage percentage (pre-calculated by Claude Code)
ctx_part=$([ -n "$used_pct" ] \
  && printf " \033[2mctx:%s%%\033[0m" "$(printf '%.0f' "$used_pct")" \
  || echo "")

# 5-hour limit bar — fixed-width substring of pre-rendered full/empty bars
# (UTF-8 substring => zero subprocesses). Colour by how close to the limit.
five_part=""
if [ -n "$five_pct" ]; then
  W=10
  FULL='██████████'
  EMPT='░░░░░░░░░░'
  pct=$(printf '%.0f' "$five_pct")
  filled=$(( (pct * W + 50) / 100 ))
  (( filled > W )) && filled=W
  (( filled < 0 )) && filled=0
  color=$( (( pct < 50 )) && echo 32 || { (( pct < 80 )) && echo 33 || echo 31; } )

  # reset countdown from resets_at epoch
  reset_part=""
  if [ -n "$resets_at" ]; then
    rem=$(( resets_at - $(date +%s) ))
    (( rem < 0 )) && rem=0
    h=$(( rem / 3600 )); m=$(( (rem % 3600) / 60 ))
    cd=$( (( h > 0 )) && printf '%dh%02dm' "$h" "$m" || printf '%dm' "$m" )
    reset_part=$(printf " \033[2m↻%s\033[0m" "$cd")
  fi

  five_part=$(printf "  \033[2m5h\033[0m \033[2m▕\033[0m\033[%sm%s\033[0m\033[2m%s▏\033[0m \033[%sm%s%%\033[0m%s" \
    "$color" "${FULL:0:filled}" "${EMPT:0:$((W - filled))}" \
    "$color" "$pct" "$reset_part")
fi

# Model display name
model_part=$([ -n "$model" ] && printf " \033[2m[%s]\033[0m" "$model" || echo "")

printf "\033[36m%s\033[0m%s%s\n%s%s%s\n" \
  "$display_dir" "$branch_part" "$hash_part" \
  "$ctx_part" "$five_part" "$model_part"
