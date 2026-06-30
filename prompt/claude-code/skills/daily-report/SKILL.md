---
name: daily-report
description: ターミナル(Claude Code/Codex)＋実世界の1日を Scrapbox の日付ページ(YYYY/M/D)に日報として記録する。収集は lifelog.py(カレンダー/Limitless/セッション/Typeless/Gmail)、整形・書込は daily-page.py(pin-diaryテンプレに分類: Schedule=カレンダー / [Limitlessライフログ] / [claude code.icon]作業。Gmailは機微情報としてtakalogへ分離)。LLMは「分類＋要約」の判断だけ担当。案件で個人(tkgshn-private)/多元現実(plural-reality)に仕分け、両方あれば相互リンク。トリガー:「日報」「日報書いて」「今日の作業まとめて」「日付ページに記録」「日付ページ更新」「ライフログ」「daily report」、作業セッションの区切り・終わり。
---

# Daily Report — 日付ページへのマルチソース日報

その日の「ターミナル作業＋実世界の活動」を Scrapbox 日付ページ(`YYYY/M/D`)に分類記録する。
**収集と整形・書込はスクリプトが決定的に行い、LLM(あなた)は「分類＋要約」の判断だけ担当する。**

```
lifelog.py gather <date>  →  [あなたが分類＋要約して curated JSON を作る]  →  daily-page.py write
   (収集)                       (判断: 個人/多元現実、要点キュレート、1行要約)        (整形・マージ・書込)
```

## 大原則
1. **収集**: `python3 ~/.claude/scripts/lifelog.py gather <YYYY-MM-DD>`（全ソース・ローカル・対話認証なし）。
2. **判断(あなたの仕事)**: gather 出力を見て — セッションを**個人/ツール vs 多元現実に分類**＋各1行要約、Limitless を**要点だけキュレート**＋要約、カレンダーは基本そのまま。→ curated JSON を組む(下記スキーマ)。
3. **整形・書込**: `daily-page.py write`（pin-diaryテンプレ・Schedule記法・灰色マーク・hashバッククォート・前後日ナビ・既存ページの管理ブロック差し替え＝全部スクリプトが決定的に処理）。手で Scrapbox 行を組まない。
4. **案件で記録先**: 個人/ツール → `tkgshn-private`(template=pin-diary) / 多元現実 → `plural-reality`(template=team)。cwdでなく内容で判断。両方に活動あれば両方 write して相互リンク。どちらも GUI の pin-diary-X が同名テンプレを生成するので([[reference_scrapbox_pin_diary]])、既存ページにマージ追記する(冪等)。
5. LLM生成本文は灰色・出典hash等は濃いまま等の整形ルールは **daily-page.py が自動適用**（あなたは要約テキストとhashを渡すだけ）。

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
Gmail は機微情報なので **takalog に分離**（別 curated JSON・gmail だけ入れる）:
```json
{ "date": "2026-05-30", "project": "takalog", "template": "gmail-takalog",
  "gmail": [{"time":"09:12","from":"メルペイ","subject":"6月のご請求...","id":"53532"}] }
```
- `schedule` = gather の `calendar` をそのまま（or 不要分を除く）。`allday:true` は「終日 📅」になる。
- `gmail` = gather の `gmail` を**そのまま渡す**(要約・本文転記しない＝index のみ)。メタデータ(time/from/subject/id)の機械抽出なので LLM 判断は不要。**メールは機微情報なので takalog に分離する**(tkgshn-private/plural-reality には入れない)。template=`gmail-takalog`・project=`takalog` の**別 curated JSON に gmail だけ**入れて write(daily-page.py が takalog 日付ページの `[📧 Gmail]` ブロックを upsert＝既存 todays-task 等は保持・各行を自動グレー化 `[( …]`)。本文が要るときは `himalaya message read -a gmail <id>` で live 取得する契約。
- `lifelog` = gather の `limitless` を**自分(LLM)で要約する**。各エントリの **`text`(生トランスクリプト)を読んで** 1行に要約する。`title`/`headings` は **Limitless の自動生成サマリで品質が低い → コピー禁止・鵜呑み禁止**(弱いヒント程度。実際 "新しい仕事について" 等が量産される)。STTノイズ・名前/単語の羅列・他者の私事(料理/通院/子供/買い物雑談等)・話者Unknownの無内容発話は**捨てる**。結果は「16件のゴミ」より「4件の本物の要約」を優先＝**少数高品質**に絞る。tkgshn 本人の活動・予定・意思決定だけを残す。
- `work` = gather の `sessions` を**個人/多元現実に分類**し、`prompt`/`last` から1行要約。`hashes` は `hash`(先頭8桁)。同トピック複数セッションは1項目に hashes を並べる。
- `work` への **WIP自動処理**追記 = gather の `wip`（[[wip-crawl]] が処理した `[claude code WIP.icon]` ページのダイジェスト）があれば、各エントリを `work` に1項目追加: summary=`[claude code WIP.icon自動処理] <title>`（`status:"skipped"` はその旨）、`links`=処理ページ `/<project>/<title>`。その日 WIP 自動処理があったことを日報に残す。
- `work[].links` = そのセッション(群)が **Scrapbox にドキュメントを書いていれば**、そのページ `/proj/Title` を入れる。gather の各 session の **`scrapbox` フィールド(=`scrapbox-write` 呼び出しから機械抽出した書込先 /proj/Title)をそのまま使う**(自分で URL を組み立てない)。複数セッションを束ねた work 項目はそれぞれの `scrapbox` を union する。**日報ページ自身(YYYY/M/D)は入れない**(lifelog 側で既に除外済み)。daily-page.py が **ハッシュ行の下に一段下げて** 灰色リンク `[( [/proj/Title]]` を出す(描画は自動)。`scrapbox` が空のセッションは `links` を付けない。
- `crosslink` = 反対側プロジェクトに同日活動があれば `/proj/YYYY/M/D`、無ければ `null`。
- **書き分け(最大3ページを別々に write)**: 個人/ツール → tkgshn-private(pin-diary) / 多元現実分があれば → plural-reality(team) / **Gmail があれば → takalog(gmail-takalog)**。tkgshn-private↔plural-reality は `crosslink` で相互リンク。

## 実行
**先回り収集(pending)**: `SessionEnd`/`PreCompact` hook が `~/.claude/.cache/daily-report/<date>.json` に gather 済みなら、手順1を省略してそれを読む(`<date>.json.reminded` は通知済みマーク)。SessionStart の additionalContext で気づいたら、この pending を使う。**書込成功後、`rm -f "$PENDING" "$PENDING.reminded"` で消費する**。pending が無ければ通常通り手順1から(hook は最適化であって必須依存ではない)。
```bash
D=$(date +%Y-%m-%d)
PENDING=~/.claude/.cache/daily-report/$D.json
[ -f "$PENDING" ] && cat "$PENDING" || python3 ~/.claude/scripts/lifelog.py gather "$D" --pretty   # 1. 収集(pending優先)
# 2. 出力を分類・要約して curated JSON を作る(上記スキーマ)。/tmp に保存
python3 ~/.claude/scripts/daily-page.py write --dry-run < curated.json   # 3a. 確認
python3 ~/.claude/scripts/daily-page.py write < curated.json             # 3b. 書込
rm -f "$PENDING" "$PENDING.reminded"                                     # 4. pending を消費(書込成功後のみ)
```
`render`(本文を stdout に出すだけ・書込なし) でプレビューも可。書込後 `/api/pages/<proj>/<encoded-date>/text` を読んで目視し、URL を報告。

## daily-page.py が出す形（参考）
pin-diary(tkgshn-private): `[tkgshn.icon]` → `[** Habbit/Task]`(既存保持) → `[** Schedule]`(カレンダー) → `[Limitlessライフログ]` → `[claude code.icon]`(作業＋crosslink) → `[** Notes]`(既存保持) → 前後日ナビ。team(plural-reality): `[** Schedule]`(カレンダー) → `[** やったこと]`(作業＋crosslink＋多元現実ライフログ) → `[** メモ]`(人間記入・既存保持) → 前後日ナビ＝GUIの pin-diary-X(makeTeamDiary)と同構成。どちらも保持ブロック(pin-diary=Habbit/Task/Notes、team=メモ)を引き継ぎ、管理ブロックだけ再生成(冪等)。**人間が書いた行は `[** ]` セクション/preamble だけでなく、管理ブロック内(nav 行の下・`[claude code.icon]` 直下など、見出し・灰色 `[( …]`・Schedule の📅行 以外の非空行)に直接書かれていても消さずに残す。** work 項目に `links` があれば各ハッシュ行の下に一段下げて `[( [/proj/Title]]` を出す。takalog(gmail-takalog): 機微な `[📧 Gmail]` ブロックを upsert(既存の Gmail ブロックを除去 → タイトル直下に再生成・各行 `[( …]` で自動グレー化・他の内容は保持)。

## 注意
- **カレンダーは遅い/best-effort**: AppleScript の繰り返し予定展開で30〜120s・たまにタイムアウト(→ gather の calendar が空)。空なら Schedule も空。詳細・ソース選定理由は [[feedback_lifelog_local_sources_over_mcp]]（Calendar.sqlitedb 直読は FDA 失効で不可、AppleScript の Automation 権限が安定）。取り込むカレンダーは `lifelog.py` の `CHECKED_CALENDARS`(祝日除外済)。
- Limitless は話者Unknown・他者私事混在＋STTノイズだらけ → `text` を読んで**自分で要約**(自動 `title` をコピーするな)・少数高品質に絞る・tkgshn-private 限定。Typeless ローカルDBは遅延(空のことが多い)。
- `date` は `%-m/%-d`(ゼロ埋め無し)。日付ページ新規作成は孤児ページではない(前後日ナビ＋相互リンクで graph に繋がる)＝[[save-to-scrapbox]]「新規は最後の手段」の許容例外。
- 書込は daily-page.py が verbatim patch(`_sbx_patch_verbatim.mjs`、消えてたら自己修復)で行う。WebSocket切断で稀に失敗 → 自動で最大3回再試行。

## 関連
- `~/.claude/scripts/lifelog.py` — 収集（calendar/limitless/sessions/typeless、サブコマンドで個別取得も可）
- `~/.claude/scripts/daily-page.py` — 整形・書込（render / write、curated JSON を stdin）
- [[save-to-scrapbox]] — Scrapbox 書き込み canonical（灰色マーク・逆時系列・アイコン）
- [[feedback_lifelog_local_sources_over_mcp]] — ソースはローカルCLI/DB優先、カレンダーはAppleScript
