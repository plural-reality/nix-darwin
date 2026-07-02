---
name: baisoku-kaigi-release-note
description: "倍速会議(Cartographer)の公開リリースノートを Scrapbox `baisoku-kaigi` に作る。既存書式に沿って新規ページを作成し、機能名をブラケット化・リリース済み機能に✅・実スクショをGyazoで埋め込み・ホームからリンク・公開APIで検証する。トリガー: 「倍速会議のリリースノート」「baisoku-kaigi にお知らせ/リリースノート」「リリースノート作って(倍速会議)」"
---

# 倍速会議 リリースノート作成

倍速会議(Cartographer)の機能をリリースしたときの、公開お知らせ(リリースノート)を Scrapbox 公開プロジェクト `baisoku-kaigi` に作る手順。
関連メモリ: reference_baisoku_kaigi_release_notes / reference_gyazo_upload_scrapbox_images / reference_scrapbox_write_gotchas。

## 前提・ツールの制約

- プロジェクトは **baisoku-kaigi**(公開・plural-reality/tkgshn-private/takalog とは別)。
- **読み**: `cosense-fetch` は baisoku-kaigi 非対応。公開 Scrapbox API を直叩きする(日本語文字化け回避で python urllib・UTF-8):
  ```sh
  python3 - <<'PY'
  import urllib.request, urllib.parse, json
  t="<page title>"
  u="https://scrapbox.io/api/pages/baisoku-kaigi/"+urllib.parse.quote(t, safe="")
  d=json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0"}),timeout=20))
  print("\n".join(l["text"] for l in d["lines"]))
  PY
  ```
  ページ一覧は `cosense-fetch --list -p baisoku-kaigi -o FILE` は使える(一覧APIは対応)。
- **書き**: `scrapbox-write -t "<title>" -p baisoku-kaigi --verbatim --mode replace < body.txt`
  - `--verbatim` = グレー無効(通常テキスト・既存ノートと同じ見た目)＋タブ/インデントをバイト単位保持。**stdin に title 行は含めない**。
  - 日本語は必ずファイル経由(argv 文字化け回避)。`export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`。
  - `--append` は hook でブロック。新規は `--mode replace`、既存改変は全文 replace(--verbatim)。
  - 書込後 URL が返っても成功証拠でない → **公開APIで再取得して行数/画像/本文を検証**。

## 書式(既存ノートに合わせる)

```
リリース日: YYYY年M月D日
対象プロダクト: 倍速会議（Cartographer）

[* 概要]
 <1〜2文。何ができるようになったか>
 [https://gyazo.com/<hash>]         ← 実スクショ

[* このリリースに含まれる機能]
 [機能名] ✅
  <説明1文>
 ...
 [https://gyazo.com/<hash>]         ← 別機能のスクショ

[* 仕組みの余談]
 <埋め込み/PCA/kmeans/LLM など裏側を余談的に。読み物として面白く>

[* 使い方]
 <画面のどこで、どう使うか>

[* ご不明点・ご相談]
 [「倍速会議」に関するお問い合わせ]
```

- **機能名・専門用語は `[...]` ブラケット**でリンク化する(例 `[じぶんレポート地図]` `[Mermaid]` `[埋め込み]` `[主成分分析]` `[k-means]`)。Scrapbox のグラフを育てる。
- **リリース済みの機能タイトルの右横に ✅** を付ける。
- 見出しは `[* 見出し]`、本文は行頭スペースでインデント。**Markdown ではない**。

## 実スクショの埋め込み(Gyazo)

プレースホルダでなく実画像を入れる。
1. 実機 Chrome でスクショ(playwright-core + `channel:'chrome'`・`NODE_PATH=<repo>/node_modules`)。フォント待ちタイムアウト回避に `await page.evaluate(()=>document.fonts.ready)` + `screenshot({clip:{...}})`。
2. Gyazo アップロード(**`dangerouslyDisableSandbox: true`** で curl・変数名は `GID` を避け `GYID`):
   ```sh
   GYID=$(cat ~/Library/Gyazo/id)
   curl -s -F "id=$GYID" -F "imagedata=@/abs/path.png" https://upload.gyazo.com/upload.cgi
   # → https://gyazo.com/<hash>
   ```
3. 本文に `[https://gyazo.com/<hash>]` で埋め込む(インライン画像化)。

## 手順

1. 既存リリースノート(`リリースノート：…`)を1〜2本、公開APIで読んで最新の書式・トーンを確認。
2. リリース内容を上記書式で下書き。機能をブラケット化、リリース済みに✅、仕組みの余談を入れる。
3. 対象機能を本番/staging で実機スクショ → Gyazo → URL 取得(機能ごとに1枚が目安)。
4. body.txt をファイルに書き、`scrapbox-write -p baisoku-kaigi --verbatim --mode replace` で作成。
5. 公開APIで再取得し、行数・gyazo画像・ブラケット・本文を検証。
6. ホーム **`倍速会議`** ページ末尾に `[<新ノートのタイトル>]` を追記(既存の画像/リンク/タブはバイト単位で保持して --verbatim replace)。
7. `open "<url>"` でユーザーの Chrome に表示。公開前レビューを求められたら、下書きを提示してから公開する。

## 注意

- 公開プロジェクトなので機微情報を書かない。デモは固有名詞なし版を使う。
- gyazo URL は半公開(推測困難だが公開)。機微でないスクショのみ。
- 本番デプロイ手順(タグ/CI)自体は reference_cartographer_deploy_infra を参照。このスキルは「リリース後の公開お知らせ」に閉じる。
