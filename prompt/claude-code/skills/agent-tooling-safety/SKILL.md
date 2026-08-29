---
name: agent-tooling-safety
description: >
  MCP server、Codex/Claude plugin、agent tool、browser bridgeなど、エージェントの権限境界・
  tool interface・ローカルbrokerを新設または変更するときに使う。トリガー: MCP、plugin、toolを作る、
  local server、browser bridge、TCC broker、agent runtime integration。
---

# Agent tooling safety

エージェント用toolは便利なshell入口ではなく、**入力・出力・副作用が明示されたcapability boundary**である。
このskillはtoolを作る／変える時だけ読む。通常のtask実行には適用しない。

## 不変条件

1. readとmutationを分ける。mutationはtyped schema、対象ID、入力検証、timeout、出力sanitizationを持つ。
2. arbitrary shell、JavaScript、SQL、AppleScript、Accessibility mutationを汎用toolとして公開しない。既存CLIより安全なschema／consent境界を増やせないwrapperは作らない。
3. local MCPはNixでpinした実体を直接起動し、原則stdioを使う。stable TCC brokerが必要な場合だけ、認証付き・mode `0600`のUnix socketを使う。認証なしlocalhost HTTPは作らない。
4. TCC権限はCodex、Terminal、汎用MCP hostに広く与えない。署名IDを持つ狭いbrokerに閉じ、許可がなければfail closedにする。TCC DBの直接変更や許可UIの自動承認は禁止する。
5. toolの直前に、対象・入力・副作用をpreviewし、当該操作への明示承認とaudit recordを得る。shell approvalやfilesystem sandboxをMCP/API側の承認とみなさない。
6. stdoutはprotocol専用、logはstderr。toolは自己完結し、機能が重複しない最小集合にする。

## 完了判定

実装・単体検証・Nix projectionだけでは足りない。対象toolのreadbackを行い、read path、mutation拒否、承認済みmutation、timeout/errorをそれぞれ確認して初めて完了とする。
