// Unit / round-trip tests for the [( … ] grey-marking contract in scrapbox-write.mjs.
// Run: node scrapbox-write.test.mjs   (pure — no @cosense/std / network needed)
//
// The contract's single source of truth is the canonical gray() in
// tkgshn-extension/llm-auto-humanize. These tests pin scrapbox-write's markGrayText to
// that contract: (1) decorated lines MERGE '(' into the deco ([* X] → [(* X]) rather than
// nesting ([( [* X]]); (2) idempotency is decided by the LEADING deco, not a substring
// scan, so prose that merely mentions the marker is still greyed.

import assert from "node:assert/strict";
import test from "node:test";
import { markGrayText, grayCore, grayBodyLines, isAlreadyGray, leadingDeco } from "./scrapbox-write.mjs";

// Reference implementation = canonical gray() from llm-auto-humanize, verbatim. markGrayText
// must agree with it on any single-segment (no backtick) line.
const canonicalGray = (core) => {
  const d = leadingDeco(core);
  return core === "" || (d && d.chars.includes("(")) ? core
    : d ? `[(${d.chars} ${d.content}]${d.rest}`
    : `[( ${core}]`;
};

test("decoration merge: headings get '(' merged into the deco, not nested", () => {
  assert.equal(markGrayText("[* 症状]"), "[(* 症状]");
  assert.equal(markGrayText("[** 一言診断]"), "[(** 一言診断]");
  assert.equal(markGrayText("[/ italic notice]"), "[(/ italic notice]");
  // The regression: the old code produced "[( [* 症状]]".
  assert.notEqual(markGrayText("[* 症状]"), "[( [* 症状]]");
});

test("plain prose wraps as [( … ]", () => {
  assert.equal(markGrayText("散文"), "[( 散文]");
  assert.equal(markGrayText("a → b (note)"), "[( a → b (note)]");
});

test("links stay inside the deco", () => {
  assert.equal(markGrayText("[[Sidekick]] 終了"), "[( [[Sidekick]] 終了]");
  assert.equal(markGrayText("[Page] 参照"), "[( [Page] 参照]");
});

test("backtick code spans stay OUTSIDE the deco", () => {
  assert.equal(markGrayText("結果は `42` だ"), "[( 結果は] `42` [( だ]");
});

test("idempotency: already-grey cores are left alone", () => {
  for (const s of ["[( foo]", "[(* 症状]", "[(** 太字]", "[( [⬜ task]]"]) {
    assert.equal(markGrayText(s), s, `markGrayText idempotent on ${s}`);
    assert.equal(markGrayText(markGrayText(s)), markGrayText(s), `double-apply stable on ${s}`);
  }
});

test("isAlreadyGray keys on the LEADING deco, not a substring", () => {
  assert.equal(isAlreadyGray("[( foo]"), true);
  assert.equal(isAlreadyGray("[(* 症状]"), true);
  assert.equal(isAlreadyGray("  [( [⬜ task]]"), true);
  // The regression: prose that *mentions* the marker must NOT be treated as already-grey.
  assert.equal(isAlreadyGray("各行を [( …] で囲む手作業の規約"), false);
  assert.equal(isAlreadyGray("[* heading]"), false);
  assert.equal(isAlreadyGray("plain"), false);
});

test("markGrayText matches canonical gray() on single-segment lines", () => {
  for (const core of ["散文", "[* 症状]", "[** x]", "[/ y]", "[( already]", "[(* merged]", "[[Bold]] note", "[Link] x"]) {
    assert.equal(markGrayText(core), canonicalGray(core), `parity on ${core}`);
  }
});

test("grayBodyLines: blanks kept, code:/table: blocks skipped, prose greyed", () => {
  const input = [
    "[* 自分で実行するコマンド]",
    " code:sh",
    "  sudo -i nix store gc",
    "  gws auth login",
    "",
    " 続きの作業",
  ];
  assert.deepEqual(grayBodyLines(input), [
    "[(* 自分で実行するコマンド]",
    " code:sh",
    "  sudo -i nix store gc",
    "  gws auth login",
    "",
    " [( 続きの作業]",
  ]);
});

test("grayBodyLines: greys a doc line that mentions the marker (no false skip)", () => {
  const input = ["LLMマーキングは各行を [( …] で囲む手作業の規約"];
  const out = grayBodyLines(input);
  assert.notEqual(out[0], input[0], "line that mentions the marker must still be greyed");
  assert.equal(out[0].startsWith("[( "), true);
});

test("grayBodyLines is idempotent (round-trip stable)", () => {
  const input = [
    "[* heading]",
    " plain line",
    " [( already grey]",
    " code:fish",
    "  brew leaves | wc -l",
    "",
    " 各行を [( …] で囲む規約の説明",
  ];
  const once = grayBodyLines(input);
  const twice = grayBodyLines(once);
  assert.deepEqual(twice, once, "applying grayBodyLines twice equals applying it once");
});
