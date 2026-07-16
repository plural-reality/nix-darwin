#!/usr/bin/env bash
# Delegate an interactive command (claude, codex, ...) to the always-on Mac mini
# in a persistent per-directory tmux session.
set -u

MINI="mac-mini"
prefix="$1"
cmd="$2"
shift 2
dir="$PWD"

if ! ssh -o ConnectTimeout=8 "$MINI" "test -d \"$dir\"" 2>/dev/null; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
  rel="${root#"$HOME"/}"
  echo "$cmd(mini): '$root' を mini へ同期中(初回のみ, node_modules 等は除外)…" >&2
  if ssh -o ConnectTimeout=8 "$MINI" "mkdir -p \"$(dirname "$root")\"" 2>/dev/null \
    && rsync -az \
      --exclude=node_modules --exclude=.next --exclude=dist --exclude=build \
      --exclude=target --exclude=.venv --exclude=venv --exclude=.direnv \
      --exclude=result --exclude=result-'*' --exclude=.turbo --exclude=.cache \
      --exclude='*.log' --exclude=.DS_Store --exclude=__pycache__ \
      "$root/" "$MINI:$rel/" >&2; then
    echo "$cmd(mini): 同期完了。" >&2
  else
    echo "$cmd(mini): '$root' の mini 同期に失敗。ローカルで動かすなら: command $cmd" >&2
    exit 4
  fi
fi

sess="${prefix}-$(basename "$dir")-$(printf '%s' "$dir" | /usr/bin/shasum | cut -c1-6)"

runcmd="$cmd"
for a in "$@"; do runcmd+=" $(printf '%q' "$a")"; done
remote="exec tmux new-session -A -s $(printf '%q' "$sess") -c $(printf '%q' "$dir") $(printf '%q' "$runcmd; exec fish -l")"
b64="$(printf '%s' "$remote" | base64 | tr -d '\n')"
exec ssh -t "$MINI" "bash -lc 'eval \"\$(printf %s $b64 | base64 --decode)\"'"
