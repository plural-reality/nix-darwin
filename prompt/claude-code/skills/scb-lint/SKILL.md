---
name: scb-lint
description: Scrapbox 3 project の健全性 Lint(Karpathy の LLM Wiki の Lint に対応)。機械的(孤立/重複/空スタブ概念ページ)を scb-lint.mjs で deterministic に検知し、意味的(矛盾/stale claim/概念ページ不足/新質問提案)を最近更新＋ローテーション部分集合の LLM パスで検知する。高精度な findings(empty-stub/duplicate/意味的)は [claude code WIP.icon] 付きの灰色の問いとして per-project キューページに自動 filing し、既存 wip-crawl が回収して解決する(Lint→Query→filing back ループ)。孤立ページはノイズが多いので digest-only(人間レビュー)。トリガー:「/scb-lint」「scb lint」「Scrapbox を lint」「wiki の健全性チェック」「孤立ページ/重複/概念ページ不足を洗い出して」、および launchd からの週次 headless 起動。
---

# scb-lint — Scrapbox wiki の健全性 Lint(self-healing の能動ループ)

Karpathy の LLM Wiki の 3 操作 Ingest / Query / Lint のうち **Lint** を担う。検知した不整合を [claude code WIP.icon] 付きの問いとして filing し、[[wip-crawl]](Query/deep-research)が回収して解決する。両者で **Lint→Query→filing back のループが自走で閉じる**。

参照(恒久ルールの canonical): [[reference_scrapbox_grey_verbatim_cosense]] / [[reference_scrapbox_write_gotchas]] / [[feedback_wip_icon_research_workflow]] / [[reference_scrapbox_merge_duplicate_pages]]

## 全体フロー
```
scb-lint.mjs --json   →  意味的パス(LLM)  →  dedup(seen.json) + 優先度/上限  →  WIP問いとして filing  →  digest
  (機械的・純検知)         (recent+rotation)      (file: stub/dup/意味的)            (per-project Scrapbox Lint)   (~/.claude/.cache/scb-lint/<date>.jsonl)
                                                  (digest: orphan)
```

## 0. 検知器のありか
```sh
# nix管理 PATH binary(未apply環境では node 直叩き)
node ~/Developer/plural-reality/nix-darwin/scripts/scb-lint.mjs --json   # 機械的 findings(JSON)
node ~/Developer/plural-reality/nix-darwin/scripts/scb-lint.mjs          # 人間向け表(filing対象とdigestを分けて表示)
```
出力 finding = `{type, severity, project, subject, fingerprint, question, url, signal}`。
- `type`: `empty-stub`(参照多いが本体空=概念ページ不足) / `duplicate`(正規化タイトル衝突) / `orphan`(被リンク0・実質本文あり)。
- `severity`: `file`(empty-stub/duplicate=高精度→WIP filing) / `digest`(orphan=ノイズ多→レポートのみ)。
- 機械的スキャンは各 project 最新 1000 ページ(更新降順)。tail 未走査は stderr に `capped` で出る(沈黙ドロップしない)。

## 1. 機械的検知(実装済み・純関数)
`scb-lint.mjs` がメタデータ(`cosense-fetch --list` の linked/linesCount/charsCount/pin/created)だけで deterministic に出す。日付ページ・システム・取引/タスクページ(☑️⬜⏳🔖💬 等プレフィックス)は全タイプで除外済み。**ここで出る `severity:"file"` の findings をそのまま filing 候補にする。**

## 2. 意味的検知(LLM パス・本 skill が実行)
全グラフは見ない。**対象 = 最近更新ページ ∪ ローテーション部分集合**(「同時 active 6 件」の注意配分原則。1 回 6〜12 ページ程度):
- 直近 7 日に更新されたページ(`cosense-fetch --list` の updated 上位)。
- 加えて seen.json の `rotateCursor` から次の N ページ(毎回ずらして長期的に全体を薄く一巡)。
各対象ページを `cosense-fetch "<title>" -p <proj> -h 2` で関連ごと取得し、以下を判断:
- **矛盾**: 関連ページ間で事実/結論が食い違う(例: 同じ制度の数値が違う、結論が逆)。
- **stale claim**: 「現在」「todo」「予定」等が古い日付のまま放置(更新日と内容の乖離)。
- **概念ページ不足(意味的)**: 本文が繰り返し言及する主題に対応するハブページが無い(機械的 empty-stub の意味版)。
- **新質問の提案(成長方向)**: そのページ群から自然に立つ未解決の問い。
出力は機械的 finding と同じ形 `{type:"contradiction"|"stale"|"concept-gap"|"question", severity:"file", project, subject, fingerprint, question, url, signal}` に揃える。fingerprint = `<type>|<project>|<正規化subject>`。

## 3. dedup と上限(filing の判断は seen.json が SoT)
- ledger: `~/.claude/.cache/scb-lint/seen.json` = `{ "<fingerprint>": {firstSeen, lastFiled, status, type, project}, "rotateCursor": {<project>:<int>} }`。
- `severity:"file"` の finding のうち **seen に無いものだけ**を新規 filing 候補にする(既出は status に関わらず再 filing しない=スパム防止)。
- **1 回あたり filing 上限 = 既定 8 件**(機械的優先 empty-stub→duplicate→意味的 の順)。超過は次回へ(digest に残す=沈黙ドロップ禁止)。
- 明らかなゴミ(タイトルが断片・`音威子府 メール` のような単なる索引)は skip して digest に `skipped` で残す。

## 4. filing(per-project キューページへ・灰色 WIP 問い)
filing 先 = 各 project の **`Scrapbox Lint`** ページ(無ければ新規 replace で作成、あれば prepend。**append は guard でブロックされる**)。新規作成時の冒頭:
```
 [( 自動健全性チェック(scb-lint)が検知した findings のキュー。各 [( ] は AI が立てた問い(灰色=未承認・可逆)。wip-crawl が回収して解決する。]
```
finding 1 件の書式(**WIP アイコン行だけ灰色にしない**=行頭トークンが実アイコンでないと wip-crawl が拾えない):
```
 [( <type>: <subjectを含む問い。？で終わる。内部リンク[ ]は埋めない(灰色が早閉じする)>]
	[claude code WIP.icon] <subject(一意タグ)>
	参照: [対象ページ名]
```
- 問い行は灰色 `[( … ？]`(AI 記述だから)。`？` を必ず含める(wip-crawl の `nearbyQuestion` が直前 4 行から拾う)。
- **アイコン行に subject を一意タグとして付ける(必須)**。wip-crawl の `nearbyQuestion` は `lines.indexOf(wipLine)` で位置を引くため、バラの `[claude code WIP.icon]` を複数並べると全部が最初の問いに解決される(2026-06-25 検証で実証)。trailing text 付きでもアイコン検知は通る(wip-crawl のテスト保証)。
- 内部リンク `[ページ名]` は灰色行に入れず **別の素行 `参照: [ページ名]`** に置く([[reference_scrapbox_grey_verbatim_cosense]])。
- 書込は `scrapbox-write -V`(verbatim・byte 忠実)。新規は `--mode replace`、既存は `--mode prepend`。
- 灰色フォーマット確認: `scrapbox-write -t _ -p <project> --gray --dry-run < q.txt | tail -n +2 | sed 's/^ //'`。

## 5. digest(daily-report 連携 / no silent cap)
filing / skip / digest-only(orphan) を `~/.claude/.cache/scb-lint/<YYYY-MM-DD>.jsonl` に 1 行ずつ追記(JST):
```sh
mkdir -p ~/.claude/.cache/scb-lint
printf '%s\n' "$(jq -nc --arg t "$(date +%H:%M)" --arg ty "<type>" --arg p "<project>" --arg s "<subject>" --arg st "filed|skipped|digest" --arg u "<url>" '{time:$t,type:$ty,project:$p,subject:$s,status:$st,url:$u}')" >> ~/.claude/.cache/scb-lint/$(date +%F).jsonl
```
orphan(digest-only)は件数サマリ + コンテンツ量上位のみ記録(全件は出さない・残数は明示)。

## 6. 検証(必須)
filing 後、`cosense-fetch -r "Scrapbox Lint" -p <project> -o final.json` を保存し `jq -r '.lines[].text'` で **WIP アイコン行が行頭・問い行に `？`・参照リンク intact** を実数確認。さらに `node scb-lint.mjs` を再走し、**filing 済み subject が次回 filing 候補に出ない**(seen 反映)ことを確認。

## 7. 安全策(autonomous 前提)
- 灰色 `[( ]` は**可逆**(人間が承認で昇格 / 打ち消しで却下)。だが誤検知は起きる → orphan を file しない・上限・dedup・skip を厳守。
- wip-crawl がこのキューを回収して回答を書く。**wip-crawl と scb-lint を同時刻 launchd にしない**(書込競合回避。scb-lint=週次 / wip-crawl=4h)。
- **初回は launchd 無効のまま手動で 1 project だけ filing 監督実行**してから timer を有効化する。

## 8. headless(launchd 週次)
`run.sh`(launchd から)が `.lock` 取得 → `claude -p "/scb-lint" --dangerously-skip-permissions` → trap で解放。env: `LANG/LC_ALL=ja_JP.UTF-8`、PATH 明示注入(wip-crawl の run.sh に準拠)。
```sh
# 手動: 検知だけ見る(書き込まない)
node ~/Developer/plural-reality/nix-darwin/scripts/scb-lint.mjs
```
