---
name: fix
description: >
  ユーザーが $fix を明示した時に、現在のrepoで既に定義されたformat・lint・test失敗を狭く修正する。
  特定のpackage managerやコマンドを前提にしない。
---

# Fix Checks

1. repoの `AGENTS.md`、package scripts、CI設定から正しいコマンドを特定する。
2. 失敗を最小の対象で再現し、原因と既存変更を分ける。
3. formatterで直せる部分だけをformatterへ任せ、意味のある変更は局所的に行う。
4. 失敗したチェックを再実行し、必要な場合だけ関連チェックを追加する。
5. 変更、実行したコマンド、残る失敗を短く報告する。

`yarn`、`npm`、`prettier`、特定のlint scriptが存在すると仮定しない。
