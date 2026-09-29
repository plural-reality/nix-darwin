---
name: jev-cu
description: CodexのComputer Useで短いMacアプリ・ブラウザ操作をJevに選択させ、画面の読戻しまで実行する。UI操作の待ち時間削減やJev-cuの検証に使う。
---

# Jev Computer Use

目的・操作・入力内容はエージェントが決め、Jevには現在の許可済みUI候補からの選択だけを任せる。専用CLI/APIがある作業はそちらを優先する。既知の一意な操作は同じCUA呼出し内で操作と読戻しをまとめればよく、Jevを挟まない。

## 実行経路

- Codex Desktop: 公開されている `cua_repl` で実行する。最初は `cua.getApp(...)` 又は既存の対象タブ取得だけを呼び、返されたAPI文書を読む。その後にこのskillの `scripts/runtime.mjs` をimportする。
- Chrome: `browser-automation` に従いstableなタブIDにbindする。MacアプリとしてChrome全体を操作するfallbackは作らない。
- Claude Code等: `cua_repl` が公開されていれば同じ実装を使用できる。無い場合、shellからCodexの内部APIを呼んだりGUI権限を追加しない。利用可能な既存ツールの仕様を確認し、対応driverを検証するまでJevループは未対応と報告する。skillを配備しただけでClaude Codeでも動作確認済みとは言わない。

## 1フェーズの契約

1. 現在のAXから、対象app/window/tabと操作の範囲を特定する。機微な画面は未許可のまま取得しない。
2. `targets` に現在観測した `role` と完全な `label` を明示する。候補にない要素や座標を操作しない。類似ラベルの一括許可はしない。
3. `goal` は短い英語にする。TypeSafeへ送るのはgoalとtargetsに一致する候補ラベルのみ。画面全体・スクリーンショット・入力値・無関係な既存値は送らない。ラベルに私的内容が含まれる場合、その内容とTypeSafeへの送信について許可を得てから `egressApproved: true` にする。キーを回答・ログへ出さない。
4. `verify(ax)` を必須とし、結果値や選中状態を検証する。ボタンの存在やJevの完了判断は成功証拠にしない。日付計算はコードが行う。
5. `execute: false` でpreview可能。許可済みの通常操作では追加の確認を挟まず `execute: true, authorized: true` とする。これらの引数は許可を作るものではない。送信・公開・支払・削除・認証・権限変更はこの自動ループで実行せず、各専用手順へ戻す。
6. `done` と `verified: true` の両方がある場合だけ完了。`unverified` は副作用不明なので再実行前に現状確認。`escalate` は元のエージェントが新鮮な画面から再判断する。人への質問が必須という意味ではない。

鍵は既存の `TYPESAFE_API_KEY` 又は呼出し時に指定した `keyFile` (0600)からだけ読む。自動探索しない。機械固有の保存先は下流設定で管理し、秘密をNix storeへ入れない。

[実行例・検証方法](references/runtime.md)を実行前に読む。モデルは `jev-1.13.0` に固定。モデル更新・条件緩和は同じfixtureと実機で再検証する。

## OpenJEVを使う場合

`provider: 'openjev'` を明示する。接続先は `https://api.openjev.sh/v1/systemone` に限定し、鍵は `OPENJEV_API_KEY` 又は指定した0600ファイルから読む。公式TypeSafeの鍵を流用しない。既定は引き続きTypeSafeで、自動fallbackはない。送信許可は選択した事業者に対して必要。OpenJEVは独立した中継事業者で、`openjev` は更新されるモデル別名のためバージョン固定を保証しない。公式版の精度・速度と同一と扱わず、利用する操作ごとに実測する。
