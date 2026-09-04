---
name: browser-automation
description: >
  ブラウザを伴う調査・確認・操作を、安全な境界とユーザーの実Google Chromeを優先して行う。
  トリガー: サイト確認、画面確認、URL操作、ブラウザでの検証、ログイン済みサイト。
---

# Browser automation

ブラウザは共有された排他的資源である。目的はブラウザを動かすことではなく、最小の副作用で対象システムの正本を読む／検証することにある。

## 選択順序

1. 公開情報の読取りは Web、API、専用 CLI を使う。ブラウザを開かない。
2. ログイン済み画面の読取り、対話、視覚検証は、ユーザーの実 Google Chrome に接続した Chrome plugin/native host を使う。
3. stable な tab/window ID を返す native Chrome API がある場合は、それで background 作成・操作する。
4. 前段で表現できない隔離検証だけ Playwright を使う。この場合も実 Chrome channel (`--browser chrome`)を指定する。Playwright 同梱 Chromium/Chrome for Testing を既定にしない。

Managed Codex の backend allow-list は `chrome` だけである。in-app browser (`iab`) と generic Computer Use は無効化されており、エラー時に暗黙の fallback として選ばない。Computer Use が必要な場合は、共有 desktop ではなく専用 VM/display または明示的な desktop lease を用意した一回限りの実行として扱う。

`~/.claude/scripts/pw.mjs` は既知の不適切な旧経路であり、実行しない。`npm install`、`npx`、`playwright install` を実行して依存やブラウザをその場で追加してはいけない。必要な依存は Nix/Home Manager の入力として追加し、適用後に再開する。

## 認証・プロファイル境界

- `--user-data-dir`、Cookie ファイル、プロファイル複製、保存済み資格情報の抽出を使わない。
- 実 Chrome で既に認証しているセッションを、接続済み plugin/native host 経由でだけ使う。資格情報・Cookie・認証コードを出力しない。
- 送信、購入、権限変更、削除、認証再設定は、対象・入力・副作用を直前に提示し、当該操作への明示承認を得る。

## Chrome 所有権とタブ台帳

- agent が作成した window/tab の返却 ID だけを、`connection_epoch + run_id` ごとの owned set として保持する。URL、title、tab 順、直近 focus から所有権を推測しない。
- 作成は `focused:false` / `active:false`。background 作成と stable ID を保証できない手段しかなければ、最後の視覚検証までブラウザ操作を遅らせる。
- タブを作成・再利用・handoff した最初の時点で、当該 run の **タブ台帳**に最小限を記録する。必須項目は `tab_ref`（stable ID 優先）、`origin`（`agent_created` / `user_reused_task_scoped` / `handoff`）、`purpose`、`terminal_disposition`（`close` / `retain` / `no_task_tabs`）である。機微な query、入力値、認証情報は台帳に書かない。
- ユーザー既存タブは原則として所有権を持たない。ただし、本人が「完了した作業のタブを閉じる」という task-scoped 又は継続方針を示し、当該タブをこの作業だけに再利用した場合に限り、`user_reused_task_scoped` として台帳へ登録できる。この例外でも URL の部分一致、title、タブ順から対象を推測して閉じてはいけない。
- ユーザーが表示・編集・handoff したタブ、下書き・未保存入力があるタブ、他 session の可能性があるタブ、状態が不明なタブは `retain` にする。これらを閉じるために確認状態を崩さない。
- 各操作は `snapshot -> role/name/state の一意性確認 -> 1 action -> canonical reread` の単位で行う。古い handle や index を次の操作に再利用しない。

## タブ終端ゲート（完了前の必須手順）

ブラウザを一度でも使った作業は、最終回答・`☑️` タイトル・`verified` checkpoint の**直前**に、次を順に完了する。クリック成功、画面表示、ツール完了だけでこのゲートを通過したと扱ってはいけない。

1. **状態の正本を再読込する。** 対象サービスの画面又は API を再読し、依頼された状態（例: 振込設定が休止、記帳済み、送信済み）が現在確認できることを記録する。確認不能なら作業は完了扱いにせず、タブは `retain` とする。
2. **台帳を再照合する。** 現在の run の台帳だけを読み、同時に動いている Codex/Claude session と lease/owned set を read-only で確認する。台帳外、別 session、または一意に特定できない tab/window/app/process は対象外にする。
3. **完了済みの対象だけを閉じる。** `terminal_disposition=close` の tab を stable ID で閉じる。stable ID がない場合は、安全な完全一致の再読込で一意に対象を特定でき、未保存入力・handoff がないことを確認した場合だけ閉じる。ドメイン、部分 URL、title、タブ順、直近 focus による一括・推測閉鎖は禁止する。
4. **閉鎖を再読込する。** 対象 tab が消えたことを再読し、`closed=<件数>; remaining=<件数>` 又は同等の事実を台帳に追記する。閉鎖に失敗又は曖昧さが残れば、完了を主張せず `retain` 理由を明示する。
5. **例外を明示する。** ブラウザを使わなかった場合は `no_task_tabs`、継続・承認待ち・handoff 中の場合は `retain` と理由を記録する。これは閉鎖の省略ではなく、台帳で確認済みの終端状態である。

すなわち、ブラウザを使う作業の完了条件は **対象状態の canonical readback → task タブの disposition → 閉鎖又は retain の readback** である。本人の継続方針により `user_reused_task_scoped` を閉じる場合も、この順序を必ず守る。対象状態を確認する前にタブを閉じて、確認手段を失ってはいけない。

## 完了判定

スクリーンショット、クリック成功、ツール完了は完了証拠ではない。対象ページまたは対象 API を再読し、意図した状態が確認できて初めて verified とする。ブラウザを使った場合は、さらにタブ終端ゲートの台帳結果が `closed`、`retain`（理由付き）、又は `no_task_tabs` として再読込済みでなければ、`verified`、`☑️`、または「完了」とは書かない。
