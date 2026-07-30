#!/usr/bin/env bash
# cc-reap.sh — デタッチ済み & アイドルな Claude Code (tmux) セッションを安全に間引く
#
# 真の単位はセッション = `tmux list-sessions`。kill は `tmux kill-session` でツリーごと
# (fish + claude + MCP + サブエージェント) を落とす。会話は JSONL に残り `cr` / `ch` で無損失再開。
#
# 安全ガード (この全てを満たしたものだけ kill 候補):
#   1. デタッチ済み (attached=0)              … 見ている画面は絶対に殺さない
#   2. tmux 無活動が IDLE_MIN 分を超過        … 直近まで触っていたものは残す
#   3. 会話 JSONL が ACTIVE_SEC 秒以内に書かれていない … 裏で作業中(サブエージェント等)は残す
#   4. 最近アクティブな順 KEEP 個に入っていない … 最低 KEEP 個は無条件で温存
#
# ガード#3 は「根本対策」: 以前は プロセスツリーの %CPU を「作業中」判定に使っていたが、
# fork-storm で暴走したセッションほど高 CPU になり、間引くべき当のセッションを温存してしまう
# 逆選択があった。会話 JSONL の最終書込 mtime は「実際に前進しているか」を CPU の thrash と
# 区別して測る安価(1回の stat)なシグナル。ここへ置き換えた。
# 「作業中」は本体 <sid>.jsonl だけでなく <sid>/ 配下(Task サブエージェント/agent-team の
# トランスクリプト)も含めて最新書込を見る。親へ委譲中で親 jsonl が静かでも子が書いていれば温存する。
# ponytail: これでも「子が長い外部コマンド(例: nix build)を回して数分 jsonl を書かない」間は静かに
#   見える。その隙は idle<IDLE_MIN(fresh)・newest KEEP・ACTIVE_SEC の余裕でカバーする(CPU は使わない)。
#
# kill は必ず台帳 (LEDGER) への追記が成功した時のみ実行する fail-safe (追記に失敗したら殺さない)。
# 台帳は追記専用で、殺したセッションの session-id を残すため `cr <session-id>` で後から復旧できる。
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
# glob 非マッチは literal を渡さず空に / ** で再帰(サブエージェントのトランスクリプト探索用)
shopt -s nullglob globstar

KEEP=${CC_REAP_KEEP:-12}              # 新しい順に温存する最小数
IDLE_MIN=${CC_REAP_IDLE_MIN:-720}     # 無活動しきい値(分)。既定 12h
ACTIVE_SEC=${CC_REAP_ACTIVE_SEC:-600} # 会話 JSONL がこの秒数以内に書かれていれば「作業中」= 温存。既定 10m
LEDGER=${CC_REAP_LEDGER:-$HOME/.claude/reaped-ledger.tsv} # 追記専用の kill 台帳(復旧ポインタ)
DO_KILL=0; [ "${1:-}" = "--kill" ] && DO_KILL=1
NOW=$(date +%s)

command -v tmux >/dev/null || { echo "tmux が無い"; exit 1; }
tmux has-session 2>/dev/null || { echo "tmux セッション無し"; exit 0; }

# pid→ppid / pid→command を一括取得 (pane_pid からセッション所有の claude を辿る用)
PS_SNAP=$(ps -axo pid=,ppid=,command=)

# pane_pid を根に子孫を BFS し、最初に見つかった claude の --session-id (UUID) を返す。
# tmux セッション名 (cc-XXXXXXXX 等) は session-id と一致しないため、必ずプロセスから抜く。
sid_of_pane() {
  [ -n "${1:-}" ] || return 0
  awk -v root="$1" '
    { ppid[$1]=$2; cmd[$1]=$0 }
    END{
      n=0; q[n++]=root; seen[root]=1
      for (p in ppid) { kids[ppid[p]] = kids[ppid[p]] " " p }
      for (i=0; i<n; i++) {
        x=q[i]
        if (match(cmd[x], /--session-id [0-9a-f-]+/)) {
          print substr(cmd[x], RSTART+13, RLENGTH-13); exit
        }
        m=split(kids[x], a, " ")
        for (j=1; j<=m; j++) { c=a[j]; if (c!="" && !seen[c]) { seen[c]=1; q[n++]=c } }
      }
    }' <<<"$PS_SNAP"
}

# session-id の「作業中さ」= 本体 <sid>.jsonl と サブエージェント/チーム <sid>/ 配下の
# 最新書込からの経過秒(小さいほど活発)を返す。何も無ければ -1。
# ・project ディレクトリは cwd エンコードで任意なので glob で全 project を横断する。
# ・複数一致(別 cwd から resume 等)は最も新しい mtime を採用する。
# ・同時書込/クロック差で mtime>NOW になっても負にせず 0(=最も活発) に丸める。
jsonl_age() {
  local sid="${1:-}" f m age best=-1
  [ -n "$sid" ] || { echo -1; return 0; }
  for f in "$HOME"/.claude/projects/*/"$sid".jsonl \
           "$HOME"/.claude/projects/*/"$sid"/**/*.jsonl; do
    [ -f "$f" ] || continue
    m=$(stat -f %m "$f" 2>/dev/null) || continue
    age=$(( NOW - m )); if [ "$age" -lt 0 ]; then age=0; fi
    if [ "$best" -lt 0 ] || [ "$age" -lt "$best" ]; then best=$age; fi
  done
  echo "$best"
}

# kill する前に台帳へ追記する fail-safe。追記(＝リダイレクト)が失敗したら非0を返し、呼び出し側は kill しない。
# 追記できない(open 失敗)時の bash のリダイレクトエラーは { } 2>/dev/null で握り潰す(温存表示で足りる)。
# 列: iso_ts <TAB> epoch <TAB> session_name <TAB> session_id <TAB> idle <TAB> jsonl_age
ledger_append() {
  local name="$1" sid="$2" idle="$3" jsec="$4"
  {
    [ -e "$LEDGER" ] || printf '# iso_ts\tepoch\tsession\tsession_id\tidle\tjsonl_age\n' >>"$LEDGER" || true
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date -r "$NOW" '+%Y-%m-%dT%H:%M:%S%z')" "$NOW" "$name" "${sid:-?}" "${idle}m" "${jsec}s" \
      >>"$LEDGER"
  } 2>/dev/null
}

# セッション一覧: activity<TAB>attached<TAB>created<TAB>name  (name は末尾=タブ/空白許容)
mapfile -t ROWS < <(tmux list-sessions -F '#{session_activity}	#{session_attached}	#{session_created}	#{session_name}')

# 最近アクティブな順 (activity 降順) の上位 KEEP をタグ付け(長寿命でも直近使用中なら温存)
mapfile -t KEEP_NAMES < <(printf '%s\n' "${ROWS[@]}" | sort -t'	' -k1,1nr | head -n "$KEEP" | cut -f4-)
in_keep() { local n; for n in "${KEEP_NAMES[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

printf '%-6s %-7s %-8s %-7s %s\n' STATE IDLE ATTACH JLOG SESSION
killed=0; kept=0
for row in "${ROWS[@]}"; do
  IFS=$'\t' read -r activity attached created name <<<"$row"
  idle_min=$(( (NOW - activity) / 60 ))
  # 消えかけセッションで tmux が失敗しても pipefail で run 全体を中断させない(|| で握る)
  panepid=$(tmux list-panes -t "=$name" -F '#{pane_pid}' 2>/dev/null | head -1) || panepid=""
  sid=""; [ -n "$panepid" ] && sid=$(sid_of_pane "$panepid")
  jsec=$(jsonl_age "$sid")
  jlog_disp="-"; [ "$jsec" -ge 0 ] && jlog_disp="$(( jsec / 60 ))m"

  reason=""
  [ "$attached" = "1" ] && reason="attached"
  [ -z "$reason" ] && in_keep "$name" && reason="recent$KEEP"
  [ -z "$reason" ] && [ "$jsec" -ge 0 ] && [ "$jsec" -lt "$ACTIVE_SEC" ] && reason="active"
  [ -z "$reason" ] && [ "$idle_min" -lt "$IDLE_MIN" ] && reason="fresh"

  if [ -n "$reason" ]; then
    printf '%-6s %-7s %-8s %-7s %s\n' "KEEP" "${idle_min}m" "$attached" "$jlog_disp" "$name  ($reason)"
    kept=$((kept+1)); continue
  fi

  # ここに来たものは reap 候補
  if [ "$DO_KILL" != "1" ]; then
    printf '%-6s %-7s %-8s %-7s %s\n' "reap?" "${idle_min}m" "$attached" "$jlog_disp" "$name"
    killed=$((killed+1)); continue
  fi

  # kill モード: 台帳への追記が成功した時だけ kill する (fail-safe)。
  # 追記は「破壊する前に復旧ポインタを必ず残す」ための reap 意図の記録。kill が後で失敗しても
  # 行は残る(=保守側に倒す)。これは fail-safe の要件(persist-before-destroy)としての意図的な順序。
  if ! ledger_append "$name" "$sid" "$idle_min" "$jsec"; then
    printf '%-6s %-7s %-8s %-7s %s\n' "KEEP!" "${idle_min}m" "$attached" "$jlog_disp" "$name  (ledger書込失敗→温存)"
    kept=$((kept+1)); continue
  fi
  if tmux kill-session -t "=$name"; then
    printf '%-6s %-7s %-8s %-7s %s\n' "KILL" "${idle_min}m" "$attached" "$jlog_disp" "$name"
    killed=$((killed+1))
  else
    printf '%-6s %-7s %-8s %-7s %s\n' "KILL?" "${idle_min}m" "$attached" "$jlog_disp" "$name  (kill失敗)"
    kept=$((kept+1))
  fi
done

echo "---"
if [ "$DO_KILL" = "1" ]; then
  echo "kept=$kept  killed=$killed  (KEEP=$KEEP IDLE_MIN=${IDLE_MIN}m ACTIVE_SEC=${ACTIVE_SEC}s)  台帳: $LEDGER"
else
  echo "kept=$kept  reapable=$killed  — 実際に間引くなら: $0 --kill   (会話は cr/ch で再開可)"
fi
