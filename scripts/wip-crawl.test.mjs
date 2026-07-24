// wip-crawl の純検知判定(inScopeLines)のユニットテスト。
// 実行: node wip-crawl.test.mjs （失敗時 exit 1）。ネットワーク不要(判定は純関数)。
import assert from "node:assert/strict";
import { inScopeLines, nearbyQuestion, ICON } from "./wip-crawl.mjs";

// nearbyQuestion: 行末アイコン形式は自行本文(アイコン除去)が最良候補・index 指定で重複行の誤対応なし
const NQ_LINES = ["title", "first?", " " + ICON, "x", "〜であってる？" + ICON, "x", "first?", " " + ICON];
const nqTests = () => {
  const assert2 = (a, b, msg) => { if (a !== b) { console.error("FAIL-", msg, JSON.stringify(a)); process.exitCode = 1; } else console.log("ok  -", msg); };
  assert2(nearbyQuestion(NQ_LINES, 4), "〜であってる？", "end-of-line icon: self line minus icon wins");
  assert2(nearbyQuestion(NQ_LINES, 2), "first?", "bare icon line: nearby question above");
  assert2(nearbyQuestion(NQ_LINES, 7), "first?", "duplicate bare icon line resolves by index (no indexOf mixup)");
};
nqTests();

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
// in: プレフィックス付き(整備中/委任文)アイコン(2026-07-24「全部検知」・分類は skill 側 LLM が担う)
T("prefixed icon lines (整備中/委任文) are in", () => {
  assert.equal(inScopeLines("page", ["x", "整備中" + ICON]).length, 1);
  assert.equal(inScopeLines("page", ["x", "これ調べて" + ICON]).length, 1);
  assert.equal(inScopeLines("page", ["x", "〜であってる？" + ICON]).length, 1);
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
// in: 行中・行末に埋め込まれたアイコンも拾う(2026-07-24「全部検知」で旧 ceiling を撤廃)
T("mid/end-of-line embedded icon is in (ceiling removed 2026-07-24)", () => {
  assert.equal(inScopeLines("page", ["x", "〜について" + ICON]).length, 1);
});
// 複数 in-scope 行を全部返す
T("counts multiple in-scope lines", () => {
  assert.equal(inScopeLines("page", ["x", ICON, "本文", " " + ICON]).length, 2);
});

if (process.exitCode) console.error("\nSOME TESTS FAILED"); else console.log("\nall wip-crawl tests passed");
