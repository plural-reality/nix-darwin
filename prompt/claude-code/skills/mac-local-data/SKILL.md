---
name: mac-local-data
description: >
  このMacのアプリがローカルに保存したデータを read-only で取り出す skill。
  2つの形式に対応: (1) SQLite — iMessage の履歴(chat.db) を検索・取得（送信は別途 imessage-send）。
  (2) Chromium/Electron LevelDB — Claude Desktop / Slack / Notion / Signal / VS Code 等の
  Local Storage・IndexedDB を snappy/zstd 解凍して中身を取り出す（生 grep が効かない圧縮を越える）。
  Beeper のメッセージ取得は beeper-to-scb が canonical なのでそちらへ委譲する。
  トリガー:「iMessage の履歴」「過去のメッセージ取得」「メッセージ検索」「誰と何を話したか」「chat.db」
  「ローカルアプリの中身」「Claude Desktop の会話/キャッシュ」「Electron アプリのデータ」
  「Slack/Notion のローカルデータ」「LevelDB を読んで」「アプリが保存してるデータ覗いて」
---

# mac-local-data — Mac アプリのローカル保存データを取り出す

このMacのアプリが**ディスクに残したデータ**を read-only で抽出する。「取得できるか」は3点で決まる:

1. **保存場所** — ローカルファイルか、サーバ専用か（サーバ専用なら取れない）
2. **形式** — SQLite / plist / JSON は即読める。**LevelDB は圧縮で生 grep が効かない**ので専用デコーダ必須
3. **権限** — このターミナルは Full Disk Access 前提（`~/Library/Messages/chat.db` が読めれば確定）

**契約は OS のストレージ形式が持ち、この skill は「どこを・どう読むか」のワークフローと薄いデコーダだけを持つ。** 値の保存場所をハードコードせず、形式ごとのリーダーに委譲する。

```
locate(app data dir)  →  identify(SQLite | LevelDB | plist)  →  decode(形式別 reader)  →  検索/要約
```

---

## 1. iMessage（SQLite, 全文ローカル）— 主用途

`~/Library/Messages/chat.db`。iCloud 同期なので **iPhone/iPad/他 Mac で打ったものも全部ここに入る**＝端末横断のコンテキスト。本文は modern macOS では `text` 列が NULL で、`attributedBody`（typedstream NSAttributedString）に入っている → `imessage.py` がデコードする。

```bash
python3 ~/.claude/skills/mac-local-data/scripts/imessage.py stats
python3 ~/.claude/skills/mac-local-data/scripts/imessage.py recent 20
python3 ~/.claude/skills/mac-local-data/scripts/imessage.py search "サロモン" 10   # attributedBody まで走査
python3 ~/.claude/skills/mac-local-data/scripts/imessage.py with "818062471623" 40 # 相手ごとのスレッド
python3 ~/.claude/skills/mac-local-data/scripts/imessage.py list-handles 30        # 既知の番号/メール
```

出力は TSV: `date <TAB> me|them <TAB> handle <TAB> text`。パイプして要約する。

- 連絡先名 ↔ 番号の解決は `imessage-send` skill の Contacts.app 検索が canonical（番号が分からなければそちらで引いてから `with`）。
- **送信はこの skill の責務外** → [[imessage-send]]（送信は必ず確認必須）。

## 2. Chromium/Electron LevelDB（Claude Desktop / Slack / Notion / Signal / VS Code …）

Electron アプリは状態を `<App>/Local Storage/leveldb` と `<App>/IndexedDB/<origin>.leveldb` に置く。データブロックが **Snappy/Zstd 圧縮**なので `grep`/`strings` では取れない。`chromium_leveldb.py` が SST(`.ldb`) と WAL(`.log`) を直接パースして解凍する。snappy/zstd は host を汚さない `uv run --with cramjam`（エフェメラル環境）で供給。

```bash
AS="$HOME/Library/Application Support"
DEC=~/.claude/skills/mac-local-data/scripts/chromium_leveldb.py

# 何が保存されているか（キー接頭辞）
uv run --quiet --with cramjam python "$DEC" "$AS/Claude/Local Storage/leveldb" --keys
# 値を全文検索
uv run --quiet --with cramjam python "$DEC" "$AS/Slack/Local Storage/leveldb" --grep "検索語"
# 全ダンプ（プレビュー）／ IndexedDB も同じ
uv run --quiet --with cramjam python "$DEC" "$AS/Notion/IndexedDB" --all
```

PATH はアプリの Application Support フォルダでもよい（再帰的に leveldb ストアを探す）。

**重要な限界:**
- **Local Storage = 状態・小さな文字列**。**IndexedDB = 本体データ**だが値は V8 シリアライズで、可読部分文字列は取れても型付きオブジェクトグラフは復元しない。
- アプリによっては**本文をローカルに持たない**。例: **Claude Desktop は会話本文を持たず**、状態(`clientState` / `conversations_v2`)だけ。会話本文は claude.ai サーバ側 → ローカルからは取れない（claude.ai の Export を使う）。
- ライブのアプリが掴むのは公式 leveldb ライブラリの LOCK だけ。本 reader は生ファイルを temp にコピーして読むので競合しない。

## 3. その他のローカルストア

- **Beeper**（Slack/iMessage/Twitter/Telegram/Matrix 集約）の取得は **[[beeper-to-scb]] が canonical**（Beeper Desktop MCP / localhost API）。SQLite を直接叩かずそちらを使う。
- **Safari/Chrome 履歴・メモ・写真・カレンダー・連絡先**等も大半は SQLite（`~/Library/...`）。`sqlite3 'file:PATH?mode=ro'` で同様に読める。新しい形式が出たら本 skill にレシピを足す（single source of truth）。

---

## セキュリティ（必ず意識する）

- これは Claude 固有ではなく、**ユーザ権限 + Full Disk Access で動く任意プロセスが同じことをできる**という事実。chat.db 等が丸見えである前提で扱う。
- 抽出した他者の私的内容は**話題だけ要約**し、逐語転記やページ書き込みは最小限に（[[beeper-to-scb]] と同じ規律）。
- 全て **read-only**（`mode=ro` / temp コピー）。元ストアを一切変更しない。送信・書込は別 skill の責務。

## 関連
- [[imessage-send]] — iMessage **送信**（本 skill は読み取り専用）。連絡先解決も canonical。
- [[beeper-to-scb]] — Beeper 経由のメッセージ取得（マルチプラットフォーム）の canonical。
- [[pendant-context]] — Limitless/Omi の音声ライフログ（別系統のローカル横断コンテキスト）。
