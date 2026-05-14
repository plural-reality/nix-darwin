---
name: save-to-scrapbox
description: Scrapboxにページを書き込む。「Scrapboxに保存」「スクボに入れて」「メモしておいて」等で発火。
---

# Save to Scrapbox

会話中のコンテンツをScrapboxに書き込むスキル。

トリガー: "Scrapboxに保存して", "スクボに入れて", "メモしておいて", "保存しておいて", "save to scrapbox", "ブックマークして", "scrapboxに記載して"

## 対応プロジェクト

| プロジェクト名 | 用途 | 使い分け |
|---|---|---|
| `plural-reality` | チームナレッジベース（デフォルト） | 特に指定がなければこちら |
| `tkgshn-private` | 個人メモ | 「個人の」「プライベートに」と言われた場合 |

## 書き込み方法

`scrapbox-write` コマンドを使う。stdin からページ本文を受け取り、WebSocket 経由で Scrapbox に書き込む。

- 全置換: `replace`（デフォルト）
- 追記: `append` / `--append`
- プレビュー: `--dry-run`

```bash
echo '内容をここに書く' | scrapbox-write --title "ページタイトル"
```

### 複数行の場合

```bash
cat <<'BODY' | scrapbox-write -p plural-reality -t "ミーティングメモ"
[* 議題]
 項目1
 項目2
[* 決定事項]
 決定した内容
BODY
```

### 既存ページへ追記する場合

```bash
cat <<'BODY' | scrapbox-write -p plural-reality -t "ミーティングメモ" --append
[* フォローアップ]
 明日の確認事項
 担当者に共有
BODY
```

`--append` は既存ページの末尾に stdin の内容だけを追加する。ページが未作成なら、そのまま新規作成される。

### 保存前にプレビューする場合

```bash
cat <<'BODY' | scrapbox-write -t "保存予定ページ" --dry-run
[* 要約]
 保存前にScrapbox行へ変換された内容を確認する
BODY
```

`--dry-run` は Scrapbox に書き込まず、実際に送るScrapbox行を stdout に出す。`SCRAPBOX_SID` がなくても動く。

### 重要な注意

1. **Scrapbox記法を使うこと（Markdownではない）**
   - 見出し: `[* 見出し]` (大: `[*** 見出し]`)
   - 太字: `[[太字]]`
   - リンク: `[ページ名]` or `[表示名 URL]`
   - 箇条書き: スペースインデント (` 項目`)
   - コード: `` `code` `` (インライン) / `code:filename` + インデント (ブロック)
   - テーブル: `table:名前` + TAB区切り行
   - タグ: `#タグ名`

2. **タイトル行は本文に含めない** — `--title` で指定したタイトルが自動的に1行目になる

3. **追記と全置換を混同しない**
   - 新しい本文でページ全体を置き換えるなら `replace`
   - 今ある内容を残して末尾だけ増やすなら `append`

4. **保存前に確認する** — 長い本文や既存ページへの追記は、まず `--dry-run` で出力を確認する。

5. **結果URL** — 成功時に stdout に Scrapbox ページの URL が出力される。ユーザーに報告すること。

## 環境変数

| 変数 | 用途 |
|---|---|
| `SCRAPBOX_SID` | connect.sid Cookie の値（URL デコード済み、`s:` で始まる） |

## ツイートURLの場合

ツイートURLを保存する場合は、twitter-bookmark API 経由:

```bash
curl -s -X POST http://localhost:3000/api/bookmark \
  -H "Content-Type: application/json" \
  -H "x-api-key: $TWITTER_BOOKMARK_API_KEY" \
  -d '{"url": "ツイートのURL"}'
```

前提: `twitter-bookmark` サーバーが起動中であること。
