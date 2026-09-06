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

Managed Codexの旧browser backend allow-listは`chrome`だけで、`iab`と旧pixel plugin (`computer-use@openai-bundled`) は無効である。この制約は新しいUnified Computer Use全体の禁止ではない。Chromeの調査・操作から、エラーを理由に別browserやMac全体の操作へ暗黙にfallbackしない。

Macアプリ固有の操作が必要なら、現在のtaskに公開され、対象appへの既存権限があるUnified Computer Useのapp-scoped操作を使える。専用CLI/APIを優先し、同じappへの他taskや本人の操作と競合しない範囲でbackground操作する。前面化やglobal mouse/keyboard操作は専用VM/displayまたは明示的なdesktop leaseを持つ一回限りの実行に留める。既存の金融監視などの隔離・lease条件を緩めず、追加の認証・app許可・TCC承認が必要なら本人の操作を待つ。

`~/.claude/scripts/pw.mjs`は既知の不適切な旧経路であり、実行しない。`npm install`、`npx`、`playwright install`を実行して依存やブラウザをその場で追加してはいけない。必要な依存はNix/Home Managerの入力として追加し、適用後に再開する。

## 認証・プロファイル境界

- `--user-data-dir`、Cookieファイル、プロファイル複製、保存済み資格情報の抽出を使わない。
- 実Chromeで既に認証しているセッションを、接続済みplugin/native host経由でだけ使う。資格情報・Cookie・認証コードを出力しない。
- 送信、購入、権限変更、削除、認証再設定は、対象・入力・副作用を直前に提示し、当該操作への明示承認を得る。

## Chrome所有権とタブ台帳

- agentが作成したwindow/tabの返却IDだけを、`connection_epoch + run_id`ごとのowned setとして保持する。URL、title、tab順、直近focusから所有権を推測しない。
- 作成は`focused:false` / `active:false`。background作成とstable IDを保証できない手段しかなければ、最後の視覚検証までブラウザ操作を遅らせる。
- OneTabへ退避できるのはagent-owned tabだけ。ユーザー所有tabは対象をpreviewし、明示承認なしにOneTab移動やcloseをしない。
- focusを戻す時はcompare-and-swapとし、まだagentの対象にfocusがある場合だけ復元する。ユーザーが別画面へ移った後は奪い返さない。
- tabを作成・再利用・handoffした最初の時点で、当該runの**タブ台帳**に最小限を記録する。必須項目は`tab_ref`（stable ID優先）、`origin`（`agent_created` / `user_reused_task_scoped` / `handoff`）、`purpose`、`terminal_disposition`（`close` / `retain` / `no_task_tabs`）である。機微なquery、入力値、認証情報は台帳に書かない。
- ユーザー既存tabは原則として所有権を持たない。ただし、本人が「完了した作業のtabを閉じる」というtask-scoped又は継続方針を示し、当該tabをこの作業だけに再利用した場合に限り、`user_reused_task_scoped`として台帳へ登録できる。この例外でもURLの部分一致、title、tab順から対象を推測して閉じてはいけない。
- ユーザーが表示・編集・handoffしたtab、下書き・未保存入力があるtab、他sessionの可能性があるtab、状態が不明なtabは`retain`にする。これらを閉じるために確認状態を崩さない。
- 各操作は `snapshot -> role/name/stateの一意性確認 -> 1 action -> canonical reread` の単位で行う。古いhandleやindexを次の操作に再利用しない。
- 完了時は同一connection epochのagent-owned tabを閉じる。本人の継続方針により`user_reused_task_scoped`を閉じる場合も、下のタブ終端ゲートを通過した台帳対象だけに限る。
- 整理の直前に、同時に動いているCodex/Claudeセッションと各lease/owned setをread-onlyで確認する。別セッションが所有している可能性のあるtab/window/app/processは閉じず、現runの台帳対象だけを整理する。
- Chrome pluginのagent-created tabは、`markDeliverable()`または`markHandoff()`を明示的に付けない限りturn終了時に自動で閉じる。調査・検索・中間結果・重複tabにはmarkを付けない。

## タブ終端ゲート（完了前の必須手順）

ブラウザを一度でも使った作業は、最終回答・`☑️`タイトル・`verified` checkpointの**直前**に、次を順に完了する。クリック成功、画面表示、ツール完了だけでこのゲートを通過したと扱ってはいけない。

1. **状態の正本を再読込する。** 対象サービスの画面又はAPIを再読し、依頼された状態（例: 振込設定が休止、記帳済み、送信済み）が現在確認できることを記録する。確認不能なら作業は完了扱いにせず、tabは`retain`にする。
2. **台帳を再照合する。** 現在のrunの台帳だけを読み、同時に動いているCodex/Claude sessionとlease/owned setをread-onlyで確認する。台帳外、別session、又は一意に特定できないtab/window/app/processは対象外にする。
3. **完了済みの対象だけを閉じる。** `terminal_disposition=close`のtabをstable IDで閉じる。stable IDがない場合は、安全な完全一致の再読込で一意に対象を特定でき、未保存入力・handoffがないことを確認した場合だけ閉じる。ドメイン、部分URL、title、tab順、直近focusによる一括・推測閉鎖は禁止する。
4. **閉鎖を再読込する。** 対象tabが消えたことを再読し、`closed=<件数>; remaining=<件数>`又は同等の事実を台帳に追記する。閉鎖に失敗又は曖昧さが残れば、完了を主張せず`retain`理由を明示する。
5. **例外を明示する。** ブラウザを使わなかった場合は`no_task_tabs`、継続・承認待ち・handoff中の場合は`retain`と理由を記録する。これは閉鎖の省略ではなく、台帳で確認済みの終端状態である。

すなわち、ブラウザを使う作業の完了条件は**対象状態のcanonical readback → task tabのdisposition → 閉鎖又はretainのreadback**である。本人の継続方針により`user_reused_task_scoped`を閉じる場合も、この順序を必ず守る。対象状態を確認する前にtabを閉じて、確認手段を失ってはいけない。

## 完了判定

スクリーンショット、クリック成功、ツール完了は完了証拠ではない。対象ページ又は対象APIを再読し、意図した状態が確認できて初めてverifiedとする。ブラウザを使った場合は、さらにタブ終端ゲートの台帳結果が`closed`、`retain`（理由付き）、又は`no_task_tabs`として再読込済みでなければ、`verified`、`☑️`、又は「完了」とは書かない。
