## 外部メッセージの下書き確認

- エージェントが本文を生成・編集したメール、Beeper、iMessage、DMその他の人への外部メッセージは、必ず二段階で送る。最初のターンでは送信先（相手・チャネル・返信先）と送信する本文全文を提示して停止し、その**後のユーザー発言**で未変更の下書きへの明示承認を得てから送信する。
- 本文を提示する前の「送って」「返信して」は、内容の作成依頼であって、生成された下書きの承認ではない。同じターンで起草から送信まで進めない。CLIの `--ack`、ツール実行許可、一般的な継続許可も本文承認の代わりにしない。
- 承認後に送信先、返信先、件名、本文のいずれかを変えた場合は、変更後の全文を再提示して再承認を得る。ユーザーが本文を逐語的に指定し「このまま送って」と依頼した場合だけ、その発言自体を本文承認としてよい。

## Execution Routing And Isolation

- 操作境界は **native CLI/API/Chrome API/CDP > typed MCP projection > Accessibility API > pixel-based Computer Use** の順で選ぶ。transport名ではなく、focusを伴わないtyped capabilityを優先し、前段で操作とreadbackを表現できるなら後段へ降りない。
- 通信前に変換ロジック、入力spec、fixture、検証をローカルで完成させる。ネットワーク操作はimmutableな入力から再実行できる最終phaseへまとめ、ブラウザ上の編集中状態を唯一の正本にしない。
- 通常のshell/filesystem実装はcurrent workspaceだけを書けるsandboxで行う。workspace外の書込みは対象rootを明示注入し、`danger-full-access`をambient defaultにしない。これはMCP/plugin/外部APIの副作用を拘束しないため、それぞれ別のcapability/consent境界を持たせる。
- filesystem sandboxとfocus safetyは別の不変条件である。background workからアプリをactivateせず、現在activeなアプリへのblind keystroke、`open`、`Target.activateTarget`、`windows.update({focused:true})`を使わない。ユーザーが表示を明示した場合だけ例外とする。
- TCC権限はCodex、Terminal、汎用MCP hostへ広く与えない。native APIごとの安定した署名IDを持つ狭いbrokerへ閉じ込め、権限が無ければfail closedにする。TCC DBの直接変更や許可UIの自動承認は禁止する。
- 大きい依頼は `docs/source収集 -> objective/non-goals/canonical source/write boundary/completion proofの固定 -> 実行` の3相に分ける。調査、実装、GUI、公開を1つの長いmutable phaseへ混ぜない。
- task/thread/reviewの作成前に`cwd + normalized objective + mode`で既存active taskを確認する。同一keyがあれば新規投入せずwait/read/continueし、checkoutごとのreviewは1件に保つ。
- 存在確認など期待される不在をshell failureにしない。probe結果を`present/absent/transient/auth/permanent`として表現し、retryはtransientだけ1回に制限する。

## MCP Safety

- local MCPはNixでpinした実体を直接起動し、原則`stdio`を使う。stable TCC brokerが必要な場合だけmode `0600`のUnix socketを使い、認証無しlocalhost HTTPは作らない。
- arbitrary shell/JavaScript/SQL/AppleScript/AX mutationをtoolとして公開しない。readとmutationを分け、typed schema、対象ID、入力検証、timeout、出力sanitizationを持たせる。
- mutationまたは機微データ取得は、実call直前に対象・入力・副作用をpreviewし、ユーザーの当該操作への明示承認とaudit recordを得る。Codexのshell `approval_policy`やfilesystem sandboxをMCP/API側の承認とみなさない。
- stdoutはprotocol専用、logはstderr。MCP wrapperが既存CLIより安全なschema/consent境界を導入しないならCLIをcanonicalに保つ。

## Chrome Workspace Ownership

- Chromeはユーザーと共有するexclusive resourceである。作成時に返った`windowId`/`tabId`だけを`browser_session_id/connection_epoch + run_id`単位のowned setとして保持し、URL、title、tab index、group、last-focused windowから所有権を推測しない。browser restart/disconnect/reconnectで古いsetを無効化し、stale IDではcleanupしない。
- project windowは`focused:false`、tabは`active:false`で作る。利用中のtoolがbackground作成とstable IDを保証できないなら、Chrome操作を最後のvisual verification phaseまで遅らせる。
- 完了時は同一connection epoch内のagent-owned tabをすべてcloseし、空になったagent-owned windowもcloseする。ただしユーザーがtabをactivate/編集した、表示を明示した、またはhandoffした時点で所有権を放棄しcleanup対象から外す。pre-existing tab/window/group、download、form state、historyは変更しない。agentが作ったscratch dataだけcanonical readback後に削除できる。
- OneTabは人間向けarchive adapterでありautomation APIではない。agent-owned tabへの利用は可。ユーザー所有tabは対象previewと明示承認なしにOneTab移送・closeしない。OneTab内部DOM/storageやtoolbar UIを無人操作しない。
- focus復元は、現在focusがなお当該agent-owned windowで、介在するユーザー操作が無いことを同一epoch内でcompare-and-swap確認できる場合だけ行う。それ以外は何もしない。既存GUIの整理を装って、agentが作っていない状態を削除しない。
- GUI element/window参照はactionごとにsemantic treeから再取得し、古いindex/handleを次stepへ持ち越さない。`snapshot -> role/name/stateで一意性確認 -> 1 action -> canonical reread`を1単位にする。

## Completion Evidence And Context Budget

- `dispatched`、`tool_completed`、`task_completed`、`verified`、`deployed`、`published/sent`を同義にしない。finalで完了と呼べるのはcanonical readback済みの状態だけである。
- 画像、PDF、large JSON、巨大logをsessionへ複製しない。path/hash/metadataと必要範囲だけを返し、`cat`より`rg`/`jq`/range read、tool output limitを使う。
- subagentは要約とevidence pointerを返し、生の巨大outputを親へ再送しない。notification、screenshot、Coast、task toastはrouting evidenceであってmutation完了証拠ではない。
