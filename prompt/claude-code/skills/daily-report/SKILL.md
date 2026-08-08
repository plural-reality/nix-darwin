---
name: daily-report
description: Claude/Codexと実世界の1日を日報化する。lifelog.pyでApple Calendar・Limitless・Mori・Plaud・Codex/Claude・Typeless・Gmail送受信・Beeper・Scrapbox更新・Coast Localメタを収集する。Mori/Plaud/Limitlessの全文Transcriptは日次JSONLへ分離し、daily-page.pyは個人・法人の短い日報とtakalogの機微な統合索引を安全にマージする。トリガー:「日報」「今日の作業まとめて」「日付ページ更新」「ライフログ」「daily report」。
---

# Daily Report — 日付ページへのマルチソース日報

その日の「ターミナル作業＋実世界の活動」を Scrapbox 日付ページ(`YYYY/M/D`)に分類記録する。
**収集と整形・書込はスクリプトが決定的に行い、LLM(あなた)は「分類＋要約」の判断だけ担当する。**

```
lifelog.py gather <date>  →  [あなたが分類＋要約して curated JSON を作る]  →  daily-page.py write
   (収集)                       (判断: 個人/多元現実、要点キュレート、1行要約)        (整形・マージ・書込)
```

## 大原則
1. **収集**: `python3 ~/.claude/scripts/lifelog.py gather <YYYY-MM-DD>`。MacBook Air上のローカルCLI/APIだけを使い、Mac miniへのSSHを前提にしない。各sourceはbest-effortで、1つの失敗が全体を止めない。
2. **判断(あなたの仕事)**: gather 出力を見て — セッションを**個人/ツール vs 多元現実に分類**＋各1行要約、Limitless を**要点だけキュレート**＋要約、カレンダーは基本そのまま。→ curated JSON を組む(下記スキーマ)。
3. **全文保存**: `transcript-sync` がMori/Plaud/Limitlessを `~/.claude/data/pendant-export/<source>/YYYY-MM-DD.jsonl` へ冪等同期する。Mori Journalは取得しない。Limitlessだけは必要に応じて `limitless-takalog.py` からScrapbox時間別ページにも投影する。
4. **整形・書込**: `daily-page.py write`（灰色マーク・hash・前後日ナビ・人間行の保持・管理ブロック差し替えを決定的に処理）。手で生成行を組まない。
5. **案件で記録先**: 個人/ツール → `tkgshn-private`(template=pin-diary) / 多元現実 → `plural-reality`(template=team)。cwdでなく内容で判断。両方に活動があれば相互リンクする。
6. **記録先を分ける**: 個人の短い観察は `tkgshn-private/YYYY/M/D`、法人の検証済み成果は `plural-reality/YYYY/M/D`、会話原文・私信・全source索引は `takalog/YYYY/M/D`。ToDoカンバンは日報の複製先ではなく、状態遷移するtaskだけを更新する。
7. LLM生成本文は灰色・出典hash等は濃いまま等の整形ルールを **daily-page.py が自動適用**する。

## curated JSON（あなたが作って daily-page.py に渡す）
```json
{
  "date": "2026-05-30",
  "project": "tkgshn-private",
  "template": "pin-diary",
  "icon": "tkgshn",
  "schedule": [{"time":"09:00","allday":false,"summary":"予定名","calendar":"ルーティーン"}],
  "lifelog":  [{"time":"11:23","summary":"その時間帯の会話/行動の要約"}],
  "work":     [{"summary":"作業の1行要約","hashes":["b80677fc","fdce32d9"],"links":["/tkgshn-private/そのセッションが書いたページ名"]}],
  "crosslink": "/plural-reality/2026/5/30"
}
```
機微情報の統合索引は **takalog に分離**する:
```json
{ "date": "2026-05-30", "project": "takalog", "template": "activity-takalog",
  "collection": [{"name":"Apple Calendar","state":"取得済み","detail":"3件"}, {"name":"Limitless","state":"取得済み","detail":"47件"}, {"name":"エージェント作業","state":"取得済み","detail":"8件"}, {"name":"Gmail","state":"記録なし"}, {"name":"Beeper","state":"取得済み","detail":"24件 / 5チャット"}, {"name":"Scrapbox","state":"取得済み","detail":"12件"}, {"name":"Coast Local","state":"取得済み","detail":"録画2時間"}],
  "schedule": [], "limitless_pages": [], "messages": [], "gmail": [], "work": [],
  "scrapbox": [], "coast": {}, "weekly": [] }
```
- `schedule` = gather の `calendar` をそのまま（or 不要分を除く）。`allday:true` は「終日 📅」になる。
- `gmail` = gather の送受信封筒メタをそのまま渡す。本文は転記しない。`direction` は `送信` / `受信`。本文が必要なときだけ `himalaya message read -a gmail -f '<folder>' --preview <id>` で既読化せずlive取得する。
- `messages` = gather が決定的に作ったBeeperのチャット別送受信件数・最初/最後の時刻。本文・senderはgather/pending/LLM/takalogへ渡さない。
- `limitless_pages` = `limitless-takalog.py manifest` の `pages`。全文自体は時間別子ページ、日付ページにはリンクと件数だけ置く。
- `scrapbox` = gather の当日更新ページメタ。日報ページ自身を含んでもよいが、ToDoカンバンへ複製しない。
- `coast` = 録画時間・session・top app/domainだけ。通常の日報ではOCR・画像・画面本文を読まない。
- `collection` は **gather出力を一字も判断せずそのまま渡す**。source成否はLLMが推測しない。表記は `取得済み` / `記録なし` / `一時的に取得できません` / `認証が必要`。英語のstatus語を新規表示しない。
- `lifelog` = gather の `limitless` / `mori` / `plaud` の **`text`(生Transcriptのpreview)** を読んで1行に要約する。providerの自動 `title`/summaryはコピーせず弱いヒントに留める。全文の正本は各 `archive` path。STTノイズ・名前/単語の羅列・他者の私事・無内容発話は捨て、tkgshn本人の活動・予定・意思決定だけを少数高品質で残す。
- `work` = gather の `sessions` を**個人/多元現実に分類**し、`prompt`/`last` から1行要約。`hashes` は `hash`(先頭8桁)。同トピック複数セッションは1項目に hashes を並べる。
- `work` への **WIP自動処理**追記 = gather の `wip`（[[wip-crawl]] が処理した `[claude code WIP.icon]` ページのダイジェスト）があれば、各エントリを `work` に1項目追加: summary=`[claude code WIP.icon自動処理] <title>`（`status:"skipped"` はその旨）、`links`=処理ページ `/<project>/<title>`。その日 WIP 自動処理があったことを日報に残す。
- `work[].links` はcommand dispatchから推測しない。`scrapbox` sourceのcanonical更新メタやAPI readbackで当該sessionの保存成功を確認できた場合だけ `/proj/Title` を入れる。確認できなければ空にする。
- `crosslink` = 反対側プロジェクトに同日活動があれば `/proj/YYYY/M/D`、無ければ `null`。
- **書き分け(最大3ページを別々に write)**: 個人/ツール → tkgshn-private(pin-diary) / 多元現実分があれば → plural-reality(team) / 機微な全source索引 → takalog(activity-takalog)。tkgshn-private↔plural-reality は `crosslink` で相互リンク。

## 実行
**先回り収集(pending)**: `SessionEnd`/`PreCompact` hook がmode `0700`の `~/.claude/.cache/daily-report/` にmode `0600`で gather 済みなら、手順1を省略してそれを読む(`<date>.json.reminded` は通知済みマーク)。SessionStart の additionalContext で気づいたら、この pending を使う。**書込成功後だけpendingを消費する**。pending が無ければ通常通り手順1から(hook は最適化であって必須依存ではない)。
```bash
# curated-private.json / curated-plural.json / curated-takalog.json をmode 0600で作った後、
# 以下を必ず1つのshell processとして実行する。途中失敗ならpendingを残す。
(
  set -euo pipefail
  umask 077
  D="${D:?D=YYYY-MM-DD を指定する}"
  PENDING="$HOME/.claude/.cache/daily-report/$D.json"
  LIMITLESS_STATE="$(jq -er '
    .collection | map(select(.name == "Limitless")) |
    if length == 1 then .[0].state else error("Limitless の収集状態が一意ではありません") end
  ' curated-takalog.json)"
  case "$LIMITLESS_STATE" in
    取得済み) LIMITLESS_EMPTY_ARGS=() ;;
    記録なし) LIMITLESS_EMPTY_ARGS=(--allow-empty) ;;
    *) printf 'Limitless を確定できません: %s\n' "$LIMITLESS_STATE" >&2; exit 1 ;;
  esac
  python3 "$HOME/.claude/scripts/pendant.py" -f json date "$D" --source limitless \
    | python3 "$HOME/.claude/scripts/limitless-takalog.py" write --date "$D" "${LIMITLESS_EMPTY_ARGS[@]}"
  python3 "$HOME/.claude/scripts/daily-page.py" write --dry-run < curated-private.json
  python3 "$HOME/.claude/scripts/daily-page.py" write < curated-private.json
  [[ ! -f curated-plural.json ]] || python3 "$HOME/.claude/scripts/daily-page.py" write --dry-run < curated-plural.json
  [[ ! -f curated-plural.json ]] || python3 "$HOME/.claude/scripts/daily-page.py" write < curated-plural.json
  python3 "$HOME/.claude/scripts/daily-page.py" write --dry-run < curated-takalog.json
  python3 "$HOME/.claude/scripts/daily-page.py" write < curated-takalog.json
  rm -f "$PENDING" "$PENDING.reminded"
)
```
`render` は純粋なプレビュー。書込後 `/api/pages/<proj>/<encoded-date>/text` を読み、保存した本文をcanonical readbackしてからURLを報告する。

## daily-page.py が出す形（参考）
pin-diary(tkgshn-private): `[tkgshn.icon]` → `[** Habbit/Task]`(既存保持) → `[** Schedule]` → `[Limitlessライフログ]` → `[claude code.icon]` → `[** Notes]`(既存保持) → 前後日ナビ。team(plural-reality): `[** Schedule]` → `[** やったこと]` → `[** メモ]`(既存保持) → 前後日ナビ。activity-takalog: `[** 収集状況]` → Schedule → Limitless全文リンク → メッセージ → メール → エージェント作業 → Scrapbox更新 → Coast Local → 今週の確認 → 前後日ナビ。すべて管理ブロックだけを再生成し、人間行・独自セクションを保持する。

## 注意
- **カレンダーは遅い/best-effort**: AppleScript の繰り返し予定展開で30〜120s・たまにタイムアウトする。取り込むのは本人のチェック済み7カレンダーだけ（`Taka の予定` / `takagi@plural-reality.com` / `Shunsuke Takagi (General)` / `Business` / `ルーティーン` / `Intervals.icu` / `日本の祝日`）。
- Limitless は話者Unknown・他者私事混在＋STTノイズだらけ → `text` を読んで**自分で要約**(自動 `title` をコピーするな)・少数高品質に絞る・tkgshn-private 限定。Typeless ローカルDBは遅延(空のことが多い)。
- `date` は `%-m/%-d`(ゼロ埋め無し)。日付ページ新規作成は孤児ページではない(前後日ナビ＋相互リンクで graph に繋がる)＝[[save-to-scrapbox]]「新規は最後の手段」の許容例外。
- 書込はcanonical `scrapbox-write --verbatim --expect-sha256` だけを使う。取得後の同時編集はCAS不一致で中止し、再取得なしに上書きしない。管理範囲は行数+SHA-256 markerで明示し、markerなしの旧形式や範囲内編集は人間行を守るためfail closedする。

## 関連
- `~/.claude/scripts/lifelog.py` — 収集（calendar/limitless/mori/plaud/sessions/typeless/gmail/beeper/scrapbox/coast）
- `~/.claude/scripts/transcript-sync.py` — Mori/Plaud/Limitless全文のprovider横断同期
- `~/.claude/scripts/limitless-takalog.py` — Limitless全文の時間別保存・readback
- `~/.claude/scripts/daily-page.py` — 整形・書込（render / write、curated JSON を stdin）
- [[save-to-scrapbox]] — Scrapbox 書き込み canonical（灰色マーク・逆時系列・アイコン）
- [[feedback_lifelog_local_sources_over_mcp]] — ソースはローカルCLI/DB優先、カレンダーはAppleScript
