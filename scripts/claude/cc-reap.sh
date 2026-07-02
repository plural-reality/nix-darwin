#!/usr/bin/env bash
# cc-reap.sh — デタッチ済み & アイドルな Claude Code (tmux) セッションを安全に間引く
#
# 真の単位はセッション = `tmux list-sessions`。kill は `tmux kill-session` でツリーごと
# (fish + claude + MCP + サブエージェント) を落とす。会話は JSONL に残り `cr` / `ch` で無損失再開。
#
# 安全ガード (この全てを満たしたものだけ kill 候補):
#   1. デタッチ済み (attached=0)              … 見ている画面は絶対に殺さない
#   2. tmux 無活動が IDLE_MIN 分を超過        … 直近まで触っていたものは残す
#   3. プロセスツリーに CPU_MIN% 以上の子が居ない … 裏で作業中(サブエージェント等)は残す
#   4. 最近アクティブな順 KEEP 個に入っていない … 最低 KEEP 個は無条件で温存
#
# 既定は dry-run (何も殺さない・分類表を出すだけ)。実際に殺すのは明示的に --kill を渡した時のみ。
#
# 使い方:
#   cc-reap.sh            # dry-run: 現状分類を表示 (これが安全確認そのもの)
#   cc-reap.sh --kill     # KEEP=12 / IDLE 12h 超のデタッチ・アイドルを実際に kill
#   CC_REAP_KEEP=8 CC_REAP_IDLE_MIN=360 cc-reap.sh --kill
set -euo pipefail
# tmux -F の tab/日本語出力が壊れないよう locale を自己完結で保証(素の最小環境でも動く)
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

KEEP=${CC_REAP_KEEP:-12}            # 新しい順に温存する最小数
IDLE_MIN=${CC_REAP_IDLE_MIN:-720}   # 無活動しきい値(分)。既定 12h
CPU_MIN=${CC_REAP_CPU_MIN:-1.0}     # ツリー内 %CPU がこれ以上なら「作業中」= 温存
DO_KILL=0; [ "${1:-}" = "--kill" ] && DO_KILL=1
NOW=$(date +%s)

command -v tmux >/dev/null || { echo "tmux が無い"; exit 1; }
tmux has-session 2>/dev/null || { echo "tmux セッション無し"; exit 0; }

# pid→ppid / pid→pcpu を一括取得 (ツリー CPU 集計用)
PS_SNAP=$(ps -axo pid=,ppid=,pcpu=)

# 指定 pid とその全子孫の合計 %CPU を返す (整数比較用に 100倍・切り捨て)
tree_cpu_x100() {
  awk -v root="$1" '
    { ppid[$1]=$2; cpu[$1]=$3 }
    END{
      # BFS
      n=0; q[n++]=root; seen[root]=1
      # 子リストを事前構築
      for (p in ppid){ kids[ppid[p]] = kids[ppid[p]] " " p }
      total=0
      for(i=0;i<n;i++){
        pid=q[i]; total+=cpu[pid]
        m=split(kids[pid], arr, " ")
        for(j=1;j<=m;j++){ c=arr[j]; if(c!="" && !seen[c]){seen[c]=1; q[n++]=c} }
      }
      printf "%d", total*100
    }' <<<"$PS_SNAP"
}

# セッション一覧: activity<TAB>attached<TAB>created<TAB>name  (name は末尾=タブ/空白許容)
mapfile -t ROWS < <(tmux list-sessions -F '#{session_activity}	#{session_attached}	#{session_created}	#{session_name}')

# 最近アクティブな順 (activity 降順) の上位 KEEP をタグ付け(長寿命でも直近使用中なら温存)
mapfile -t KEEP_NAMES < <(printf '%s\n' "${ROWS[@]}" | sort -t'	' -k1,1nr | head -n "$KEEP" | cut -f4-)
in_keep() { local n; for n in "${KEEP_NAMES[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

CPU_MIN_X100=$(awk -v v="$CPU_MIN" 'BEGIN{printf "%d", v*100}')
printf '%-5s %-7s %-8s %-7s %s\n' STATE IDLE ATTACH CPU% SESSION
killed=0; kept=0
for row in "${ROWS[@]}"; do
  IFS=$'\t' read -r activity attached created name <<<"$row"
  idle_min=$(( (NOW - activity) / 60 ))
  panepid=$(tmux list-panes -t "=$name" -F '#{pane_pid}' 2>/dev/null | head -1)
  cpux=0; [ -n "$panepid" ] && cpux=$(tree_cpu_x100 "$panepid")
  cpu_h=$(awk -v x="$cpux" 'BEGIN{printf "%.1f", x/100}')

  reason=""
  [ "$attached" = "1" ] && reason="attached"
  [ -z "$reason" ] && in_keep "$name" && reason="recent$KEEP"
  [ -z "$reason" ] && [ "$cpux" -ge "$CPU_MIN_X100" ] && reason="busy"
  [ -z "$reason" ] && [ "$idle_min" -lt "$IDLE_MIN" ] && reason="fresh"

  if [ -n "$reason" ]; then
    printf '%-5s %-7s %-8s %-7s %s\n' "KEEP" "${idle_min}m" "$attached" "$cpu_h" "$name  ($reason)"
    kept=$((kept+1))
  else
    if [ "$DO_KILL" = "1" ]; then
      tmux kill-session -t "=$name" && printf '%-5s %-7s %-8s %-7s %s\n' "KILL" "${idle_min}m" "$attached" "$cpu_h" "$name"
    else
      printf '%-5s %-7s %-8s %-7s %s\n' "reap?" "${idle_min}m" "$attached" "$cpu_h" "$name"
    fi
    killed=$((killed+1))
  fi
done

echo "---"
if [ "$DO_KILL" = "1" ]; then
  echo "kept=$kept  killed=$killed  (KEEP=$KEEP IDLE_MIN=${IDLE_MIN}m CPU_MIN=${CPU_MIN}%)"
else
  echo "kept=$kept  reapable=$killed  — 実際に間引くなら: $0 --kill   (会話は cr/ch で再開可)"
fi
