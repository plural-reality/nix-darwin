// Unit tests for the VS16-normalization contract in scrapbox-title-normalize.mjs.
// Run: node scrapbox-title-normalize.test.mjs   (pure — no @cosense/std / network needed)
//
// These pin the canonical byte form of every status emoji: text-default chars
// (☑ ⏹ ⚠) carry exactly one VS16, emoji-default chars (⬜ ⏳ ⌛ ✅ ❌ 🚨) carry
// none, and a stray leading VS16 (left behind when a prefix emoji was stripped)
// is removed. Each case is a real breakage class measured on 2026-07-24.

import assert from "node:assert/strict";
import test from "node:test";
import { normalizeStatusEmoji } from "./scrapbox-title-normalize.mjs";

test("double VS16 collapses to one (the 20-page インド出張 breakage)", () => {
  assert.equal(normalizeStatusEmoji("☑️️高木インド出張"), "☑️高木インド出張");
});

test("missing VS16 on a text-default char is added", () => {
  assert.equal(normalizeStatusEmoji("⏹ どこに次の法人を置くべきか"), "⏹️ どこに次の法人を置くべきか");
  assert.equal(normalizeStatusEmoji("☑バクラク解約"), "☑️バクラク解約");
});

test("redundant VS16 on an emoji-default char is dropped", () => {
  assert.equal(normalizeStatusEmoji("⬜️社会保険の新規適用届"), "⬜社会保険の新規適用届");
  assert.equal(normalizeStatusEmoji("⌛️️音威子府PJの経費精算"), "⌛音威子府PJの経費精算");
});

test("stray leading VS16 (stripped-emoji residue, the 13-page 勉強会 breakage) is removed", () => {
  assert.equal(normalizeStatusEmoji("️構想日本と共に議員向け勉強会を開催する"), "構想日本と共に議員向け勉強会を開催する");
});

test("already-canonical titles pass through byte-identical", () => {
  const canon = ["☑️完了タスク", "⏳cc: 実行中タスク", "\u{1F6A8}判断待ちタスク", "絵文字なしタイトル"];
  canon.forEach((t) => assert.equal(normalizeStatusEmoji(t), t));
});

test("mid-title status chars are normalized too (links in prose share the hazard)", () => {
  assert.equal(normalizeStatusEmoji("経緯は ☑️️旧タスク を参照"), "経緯は ☑️旧タスク を参照");
});

test("VS16 after a non-status char is left alone", () => {
  assert.equal(normalizeStatusEmoji("©️ copyright page"), "©️ copyright page");
});
