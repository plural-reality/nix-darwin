#!/bin/bash
# daily-report-remind.sh
# SessionStart hook(同期)から呼ばれる、daily-report の「気づき」段。
# その日の pending gather があれば additionalContext で控えめに知らせるだけ(強制しない)。
# 同一 pending では一度しか通知しない(毎セッション鬱陶しくしない)。
set -euo pipefail

CACHE="$HOME/.claude/.cache/daily-report"
DATE="$(TZ=Asia/Tokyo date +%Y-%m-%d)"
PENDING="$CACHE/$DATE.json"
MARK="$PENDING.reminded"

[ -f "$PENDING" ] || exit 0   # pending 無ければ静かに終了(additionalContext を出さない)
[ -f "$MARK" ] && exit 0      # 通知済みなら出さない
: > "$MARK"

# additionalContext は python3 の json.dumps で1行 JSON として生成する(改行は確実に \n へエスケープ)。
# 依存を lifelog.py と同じ python3 に統一する意図。
CTX="📝 未処理の daily-report gather が ${DATE} にあります: ${PENDING}
ユーザーが「日報」「今日のまとめ」等を希望したら、この gather を再取得せず読み込み、daily-report スキルで分類・要約して Scrapbox 日付ページに書き込んでください。書込成功後は ${PENDING} と ${MARK} を削除してください(消費)。今のタスクと無関係なら一切言及しないでください。"

CTX="$CTX" python3 -c "import json,os; print(json.dumps({'hookSpecificOutput':{'hookEventName':'SessionStart','additionalContext':os.environ['CTX']}}, ensure_ascii=False))"
