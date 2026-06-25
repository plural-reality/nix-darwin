// wip-crawl の純検知判定(inScopeLines)のユニットテスト。
// 実行: node wip-crawl.test.mjs （失敗時 exit 1）。ネットワーク不要(判定は純関数)。
import assert from "node:assert/strict";
import { inScopeLines, ICON } from "./wip-crawl.mjs";

const T = (name, fn) => { try { fn(); console.log("ok  -", name); } catch (e) { console.error("FAIL-", name, "\n", e.message); process.exitCode = 1; } };

// in-scope: 行頭が実アイコン（単独）
T("standalone icon is in-scope", () => {
  assert.equal(inScopeLines("Q?", ["Q?", " \t" + ICON]).length, 1);
});
// in-scope: アイコン + 末尾テキスト「これ調査して」
T("icon + trailing text is in-scope", () => {
  assert.equal(inScopeLines("page", ["x", "  \t" + ICON + "これ調査して"]).length, 1);
});
// in-scope: 全角空白インデント
T("full-width-space indent icon is in-scope", () => {
  assert.equal(inScopeLines("page", ["x", "　　　" + ICON]).length, 1);
});
// out: 整備中プレフィックス(進行中タスク)
T("整備中-prefixed icon is out", () => {
  assert.equal(inScopeLines("page", ["x", "整備中" + ICON]).length, 0);
});
// out: 自動取込セッションログ(2行目が from [claude codeセッション])
T("session-log import is out", () => {
  assert.equal(inScopeLines("ログ", ["ログ", "from [claude codeセッション]", ICON]).length, 0);
});
// out: アイコン定義ページ
T("icon-definition page is out", () => {
  assert.equal(inScopeLines("claude code WIP", ["claude code WIP", ICON]).length, 0);
});
// out: 全角ブラケットの引用（実アイコンではない）
T("full-width-bracket quote is out", () => {
  assert.equal(inScopeLines("page", ["x", "［claude code WIP.icon］"]).length, 0);
});
// out: 行中・行末に埋め込まれたアイコン（ponytail で既知の上限）
T("mid/end-of-line embedded icon is out (known ceiling)", () => {
  assert.equal(inScopeLines("page", ["x", "〜について" + ICON]).length, 0);
});
// 複数 in-scope 行を全部返す
T("counts multiple in-scope lines", () => {
  assert.equal(inScopeLines("page", ["x", ICON, "本文", " " + ICON]).length, 2);
});

if (process.exitCode) console.error("\nSOME TESTS FAILED"); else console.log("\nall wip-crawl tests passed");
