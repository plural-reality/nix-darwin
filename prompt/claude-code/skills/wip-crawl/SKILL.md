---
name: wip-crawl
description: Scrapbox 3 project を横断して未処理の [claude code WIP.icon]（=tkgshn の未解決の問い）を検知し、各ページをディープリサーチ→灰色 [( ] で in-place 回答→アイコン削除→？タイトルは →結論+☑️ rename→再フェッチ検証 まで自動処理する。処理結果はダイジェストに記録し daily-report に乗せる。source of truth は Scrapbox 自身（アイコンが消える=処理済=キューから外れる self-draining queue）。トリガー:「/wip-crawl」「WIPをクロール」「scbのWIPを処理」「未処理の問いを調べて」「scb-mention-deep-research」、および launchd からの headless 起動。
---

# wip-crawl — Scrapbox の [claude code WIP.icon] 未処理キューを自律処理する

`[claude code WIP.icon]` を **Scrapbox 全体の「未解決の問い」キュー**として扱い、検知→ディープリサーチ→灰色回答→アイコン削除まで回す。状態は別管理しない（**アイコンの有無が唯一の真実**）。

参照（恒久ルールの canonical）: [[feedback_wip_icon_research_workflow]] / [[reference_scrapbox_grey_verbatim_cosense]] / [[reference_scrapbox_write_gotchas]] / [[scrapbox-rename-replacelinks-403-deeplink-fallback]]

## 全体フロー
```
wip-crawl.mjs --json   →  各ページを処理(リサーチ→灰色書込→アイコン削除→必要なら rename→検証)  →  digest 追記  →  daily-report
   (検知・純関数)             (1ページずつ。上限あり)                                                  (~/.claude/.cache/wip-crawl/<date>.jsonl)
```

## 1. 検知（純フィルタ・実装済み）
```sh
wip-crawl --json   # nix管理の PATH binary。未apply環境では node <nix-darwin>/scripts/wip-crawl.mjs --json
```
出力 = 処理対象 `[{project,title,url,wipCount,questions}]`。in-scope の定義（`inScopeLines`）= **行頭の非空白トークンが `[claude code WIP.icon]`**。除外済み: `整備中…`（進行中タスク）/ 自動取込ログ(`from [claude codeセッション]`) / アイコン定義ページ / 全角 `［…］` 引用。**1回あたり上限（既定5件）**で処理し、超過は次回へ（`log()`/digest に残す）。

## 2. ページごとの処理（4回の実運用で確立した手順）
各対象 `{project,title}` に対して:

1. **取得**: `cosense-fetch -r "<title>" -p <project> -o page.json`（特殊文字タイトルは redirect でなく `-o` 必須）。`.lines[].text` を ground truth に。
2. **スコープ再判定**: アイコン行の直前数行に明確な問い（`？`/`[tkgshn.icon]`）があるか。曖昧・進行中タスク（整備中）は **skip**（digest に skipped で残す）。
3. **ディープリサーチ**: 内部(Scrapbox/該当ページの越境リンク・内部 transcript)＋外部(Web)。多角度の web-search-researcher を並列 fan-out → 敵対的検証 → 統合（Workflow 推奨）。一次ソース＋出典URLを必ず確保。途中で出た誤情報は除外。
4. **回答の作文（既定=中:結論＋根拠＋誤解の出所/含意）**:
   - AI 散文は灰色 `[( …]`。**人間の素の行（`from …`/`…？[tkgshn.icon]`/`要リサーチ` 等）は触らず verbatim 保全**。
   - 出典リンク行・画像行は **素のまま**（灰色にしない）。
   - グレー行に内部リンク `[ページ名]` を埋めると `]` でグレーが**早閉じ**する → リンクは**別の素行**（`参照: [ページ名]`）に分離。
   - 制度要綱の全文などリンク先に既にある内容は**重複させない**。
   - グレー化フォーマット確認: `scrapbox-write -t _ -p <project> --gray --dry-run < ai.txt | tail -n +2 | sed 's/^ //'`（`[( X]` を得る）。手書きで `[( …]` を付けても可（verbatim 時）。
5. **in-place 置換**: 生 `.lines` を読み、**WIPアイコン行を回答行に差し替え**（同じ字下げを保持）、他は全行 verbatim。`-V/--verbatim --mode replace`（stdin はタイトル行を含めない）で書込。
   - ハブ内に多数リンクがあり調査本体が長い場合のみ別ページ切り出し（`feedback_wip_icon_research_workflow` step4）。独立した「？」リーフページは in-place。
6. **タイトルが「？」のページ**: `scrapbox-rename <project> "旧" "新"`。新タイトル = **文頭 `☑️` ＋ 末尾 `→<簡潔な断定結論>`**。`replaceLinks` が 403 でも `deepLinkPagesFixed` が補完しうる → **親ページを grep で被リンク確認**（[[scrapbox-rename-replacelinks-403-deeplink-fallback]]）。タイトルが疑問形でない（解説/概要）ページは rename しない。
7. **検証（必須）**: `cosense-fetch -r "<新title>" -p <project> -o final.json` を保存し、`jq -r '.lines[].text'` で **WIPアイコン=0 / 回答反映 / 人間の素行 intact / id 保持** を実数確認。未反映ならリトライ。
8. **digest 追記**: 下記 jsonl に1行追記。

## 3. ダイジェスト（daily-report 連携の SoT）
処理1ページにつき `~/.claude/.cache/wip-crawl/<YYYY-MM-DD>.jsonl` に1行追記（JST）:
```sh
mkdir -p ~/.claude/.cache/wip-crawl
printf '%s\n' "$(jq -nc --arg t "$(date +%H:%M)" --arg p "<project>" --arg ti "<title>" --arg s "<1行要約=結論>" --arg u "<url>" --arg st "done" '{time:$t,project:$p,title:$ti,summary:$s,url:$u,status:$st}')" >> ~/.claude/.cache/wip-crawl/$(date +%F).jsonl
```
`skip` した問いも `status:"skipped"`＋理由で残す（沈黙のドロップ禁止）。

`lifelog.py` に `wip` ソースを追加済み → `daily-report` がこの digest を `work` 欄に `[claude code WIP.icon自動処理] <title>` として記載する。

## 4. 安全策（autonomous 前提）
- 灰色 `[( ]` は**可逆**（人間が後で承認/打ち消し却下できる）。だが研究の誤りも書かれうる → 一次ソース＋敵対的検証を必須。
- **1回あたり処理上限**（既定5件）。超過分は digest に残し次回。
- **同時実行制御は run.sh ラッパーが単独で担う**（run.sh が `.lock` 取得→claude 実行→trap で解放）。**skill 側ではロックを見ない**＝自分の親 run.sh のロックを誤検知して即終了するデッドロックを防ぐ（2026-06-25 の監督テストで実証・修正）。手動 `/wip-crawl` は run.sh を介さずロック無しで処理する。
- 整備中/セッションログ/曖昧な問いは処理しない。
- 書込後の再フェッチ検証を**毎回**通す（[[reference_scrapbox_write_gotchas]]）。

## 5. headless（launchd 高頻度実行）
launchd から `claude -p "/wip-crawl"`（または wrapper）で起動。env: `LANG/LC_ALL=ja_JP.UTF-8`、`SCRAPBOX_SID` は settings.json から。既存 `claude-log-to-scb` の launchd パターンに準拠。**初回は launchd 無効のまま手動で1ページ監督実行**してから timer を有効化する。
```sh
# 手動: 検知だけ見る
wip-crawl
```
