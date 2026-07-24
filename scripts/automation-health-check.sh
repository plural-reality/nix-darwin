#!/usr/bin/env bash
# Claude Code SessionStart hook.
#
# Scrapbox 自動化ジョブ(wip-crawl / todo-kanban-autoupdate / scb-lint)のサイレント故障を
# セッション開始時に検知して警告する。過去の実害: 誤 host activate で isMini ジョブが2日間
# 全滅(2026-07-19) / skill 名不一致で14サイクル無言失敗(exit 0 のため launchd からは正常に
# 見える, 2026-07-08)。launchd 側は成功を装うので、成果物(run.log)の鮮度と既知の失敗文字列を
# セッション側から毎回見るのが確実(2026-07-24 ユーザー承認)。
set -uo pipefail

# ジョブは isMini 限定なので mini 以外では検査しない
case "$(hostname 2>/dev/null)" in
  tkgshn-mac-mini*) ;;
  *) exit 0 ;;
esac

CACHE="$HOME/.claude/.cache"
WARNS=()

# name / run.log パス / 閾値(分)。4hジョブ=300分(1周期+1h猶予)、週次=11520分(8日)。
check_fresh() {
  local name="$1" log="$2" maxmin="$3"
  [ -e "$log" ] || { WARNS+=("${name}: run.log が存在しない(一度も走っていない/誤 host activate の疑い)"); return; }
  if [ -n "$(find "$log" -mmin +"$maxmin" 2>/dev/null)" ]; then
    WARNS+=("${name}: 最終更新が閾値(${maxmin}分)超過(launchd 停滞・誤 host activate・deadlock の疑い)")
  elif tail -n 40 "$log" 2>/dev/null | grep -q 'Unknown command'; then
    WARNS+=("${name}: 直近ランに 'Unknown command'(skill 名不一致で無言失敗中)")
  fi
}

check_fresh "wip-crawl(4h毎)" "$CACHE/wip-crawl/run.log" 300
check_fresh "todo-kanban-autoupdate(4h毎)" "$CACHE/todo-kanban-autoupdate/run.log" 300
# scb-lint は週次(日曜4:30)。ログは日付 jsonl or run.log のどちらか新しい方
SCB_LINT_LATEST=$(ls -t "$CACHE/scb-lint"/* 2>/dev/null | head -1)
[ -n "${SCB_LINT_LATEST:-}" ] && check_fresh "scb-lint(週次)" "$SCB_LINT_LATEST" 11520

[ ${#WARNS[@]} -eq 0 ] && exit 0

MSG="⚠️ Scrapbox 自動化ジョブの死活監視: $(printf '%s / ' "${WARNS[@]}")対処: まず「launchctl list | grep nix-community」で isMini ジョブの生存確認。居ない場合は誤 host activate → sudo darwin-rebuild switch --flake .#tkgshn-mac-mini。詳細は memory reference_todo_kanban_autoupdate。"
jq -cn --arg c "$MSG" '{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$c}}'
