---
name: browser-automation
description: "ブラウザを伴う調査・確認・操作を、安全な境界と実Chromeを優先して行う。トリガー: サイト確認、画面確認、URL操作、ブラウザでの検証。"
---

# Browser Automation

ブラウザは共有された排他的資源である。目的はブラウザを動かすことではなく、最小の副作用で対象システムの正本を読む／検証することにある。

## 選択順序

1. **公開情報の読取り**は Web/API/専用CLI を使う。ブラウザを開かない。
2. **ログイン済み画面の読取り、対話、視覚検証**は、ユーザーの実Google Chrome に接続した Chrome plugin/native host を使う。
3. 安定した tab/window ID を返す native Chrome API がある場合は、それで background 作成・操作する。
4. 上記で表現できない隔離検証だけ Playwright を使う。この場合も `--browser chrome` で実Chrome channel を指定する。Playwright 同梱 Chromium/Chrome for Testing を既定にしない。

`~/.claude/scripts/pw.mjs` は既知の不適切な旧経路であり、実行しない。`npm install`、`npx`、`playwright install` を実行して依存やブラウザをその場で追加してはいけない。必要な依存は Nix/Home Manager の入力として追加し、適用後に再開する。

## 認証・プロファイル境界

- `--user-data-dir`、Cookie ファイル、プロファイル複製、保存済み資格情報の抽出を使わない。
- ユーザーが実Chromeで既に認証しているセッションを、接続済み plugin/native host 経由でのみ使う。資格情報・Cookie・認証コードを出力しない。
- 送信、購入、権限変更、削除、認証再設定は、対象・入力・副作用を直前に提示し、当該操作への明示承認を得る。

## Chrome 所有権

- agent が作成した window/tab の返却 ID を、`connection_epoch + run_id` ごとの owned set として保持する。URL、タイトル、タブ順、直近focusから所有権を推測しない。
- 作成は `focused:false` / `active:false`。background 作成と stable ID を保証できない手段しかなければ、最後の視覚検証までブラウザ操作を遅らせる。
- 各操作は `semantic snapshot -> role/name/state の一意性確認 -> 1 action -> canonical reread` の単位で行う。古いハンドルやindexを次の操作に再利用しない。
- 完了時は同一 connection epoch の agent-owned tab だけを閉じる。ユーザーが表示・編集・handoffした時点で所有権を放棄し、既存の tab/window/history/download/form state は変更しない。

## 完了判定

スクリーンショット、クリック成功、ツール完了は完了証拠ではない。対象ページまたは対象APIを再読し、意図した状態が確認できて初めて検証済みとする。
