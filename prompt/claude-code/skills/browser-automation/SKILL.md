---
name: browser-automation
description: >
  ブラウザを伴う調査・確認・操作を、安全な境界とユーザーの実Google Chromeを優先して行う。
  トリガー: サイト確認、画面確認、URL操作、ブラウザでの検証、ログイン済みサイト。
---

# Browser automation

ブラウザは共有された排他的資源である。目的はブラウザを動かすことではなく、最小の副作用で対象システムの正本を読む／検証することにある。

## 選択順序

1. 公開情報の読取りはWeb、API、専用CLIを使う。ブラウザを開かない。
2. ログイン済み画面の読取り、対話、視覚検証は、ユーザーの実Google Chromeに接続したChrome plugin/native hostを使う。
3. stableなtab/window IDを返すnative Chrome APIがある場合は、それでbackground作成・操作する。
4. 前段で表現できない隔離検証だけPlaywrightを使う。この場合も実Chrome channel (`--browser chrome`)を指定する。Playwright同梱Chromium/Chrome for Testingを既定にしない。

Managed Codexのbackend allow-listは`chrome`だけである。in-app browser (`iab`) とgeneric Computer Useは無効化されており、エラー時に暗黙のfallbackとして選ばない。Computer Useが必要な場合は、共有desktopではなく専用VM/displayまたは明示的なdesktop leaseを用意した一回限りの実行として扱う。

`~/.claude/scripts/pw.mjs`は既知の不適切な旧経路であり、実行しない。`npm install`、`npx`、`playwright install`を実行して依存やブラウザをその場で追加してはいけない。必要な依存はNix/Home Managerの入力として追加し、適用後に再開する。

## 認証・プロファイル境界

- `--user-data-dir`、Cookieファイル、プロファイル複製、保存済み資格情報の抽出を使わない。
- 実Chromeで既に認証しているセッションを、接続済みplugin/native host経由でだけ使う。資格情報・Cookie・認証コードを出力しない。
- 送信、購入、権限変更、削除、認証再設定は、対象・入力・副作用を直前に提示し、当該操作への明示承認を得る。

## Chrome所有権

- agentが作成したwindow/tabの返却IDだけを、`connection_epoch + run_id`ごとのowned setとして保持する。URL、title、tab順、直近focusから所有権を推測しない。
- 作成は`focused:false` / `active:false`。background作成とstable IDを保証できない手段しかなければ、最後の視覚検証までブラウザ操作を遅らせる。
- 各操作は `snapshot -> role/name/stateの一意性確認 -> 1 action -> canonical reread` の単位で行う。古いhandleやindexを次の操作に再利用しない。
- 完了時は同一connection epochのagent-owned tabだけを閉じる。ユーザーが表示・編集・handoffした時点で所有権を放棄し、既存のtab/window/history/download/form stateは変更しない。
- 整理の直前に、同時に動いているCodex/Claudeセッションと各lease/owned setをread-onlyで確認する。別セッションが所有している可能性のあるtab/window/app/processは閉じず、現runの同一epochで作成したIDだけを整理する。
- Chrome pluginのagent-created tabは、`markDeliverable()`または`markHandoff()`を明示的に付けない限りturn終了時に自動で閉じる。調査・検索・中間結果・重複タブにはmarkを付けない。

## 完了判定

スクリーンショット、クリック成功、ツール完了は完了証拠ではない。対象ページまたは対象APIを再読し、意図した状態が確認できて初めてverifiedとする。
