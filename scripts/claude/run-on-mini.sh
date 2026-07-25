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
# トランスポートは mosh を既定にする。ssh は文字単位モードなので「1打鍵 = 1 RTT」が
# 構造的に避けられず、モバイル回線(新幹線/テザリング)では体感が壊れる。mosh は
# 投機的ローカルエコー(-a)で打鍵を即座に描画し、UDP なので TCP の head-of-line
# ブロッキングも起きない。さらに mosh-server が向こう側で pty を保持し続けるため、
# 回線が切れても tmux の detach/attach が発生せず、再接続時のジオメトリ破綻も起きない。
# -o(--predict-overwrite): fish の autosuggestion は「候補をカーソル位置のテキストが
#   上書きする」前提なので、予測を挿入すると灰色候補が右へ押し出される(mosh#932)。
# MOSH_SERVER_NETWORK_TMOUT: 無指定だと mosh-server が永久に待ち、再接続のたびに
#   ゾンビが積み上がって同じ tmux セッションに居座る。7日で自壊させる。
# LANG: mosh-server は UTF-8 ロケールが無いと起動を拒否する。
# mosh が無い環境、および UDP(60000-61000)が塞がれた網では
# RUN_ON_MINI_TRANSPORT=ssh で従来どおり ssh に退避できる(同じ tmux セッションに入る)。
if [ "${RUN_ON_MINI_TRANSPORT:-mosh}" = mosh ] && command -v mosh >/dev/null 2>&1; then
  exec mosh -a -o \
    --server="env MOSH_SERVER_NETWORK_TMOUT=604800 LANG=en_US.UTF-8 mosh-server" \
    "$MINI" -- bash -lc "eval \"\$(printf %s $b64 | base64 --decode)\""
fi

exec ssh -t "$MINI" "bash -lc 'eval \"\$(printf %s $b64 | base64 --decode)\"'"
