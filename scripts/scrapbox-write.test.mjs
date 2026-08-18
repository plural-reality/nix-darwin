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
import {
  decideWriteTitle,
  grayBodyLines,
  grayCore,
  guardPatchStrategy,
  isAlreadyGray,
  leadingDeco,
  linesDigest,
  markGrayText,
  matchClose,
  validateBoardWrite,
} from "./scrapbox-write.mjs";

// --- decideWriteTitle: 正規化先を選ぶのは「不在を確認できた時だけ」 ---------------
// SID 失効時の 403 で既存ページを正規形の別ページへ逸らすと二重化を自ら起こす(2026-07-24 Codex レビュー High)。
test("decideWriteTitle: exact page exists (200 persistent) → keep given title", () => {
  assert.equal(decideWriteTitle("☑️️X", "☑️X", 200, { persistent: true }), "☑️️X");
});
test("decideWriteTitle: phantom (200 persistent:false) → normalized", () => {
  assert.equal(decideWriteTitle("☑️️X", "☑️X", 200, { persistent: false }), "☑️X");
});
test("decideWriteTitle: 404 (confirmed absent) → normalized", () => {
  assert.equal(decideWriteTitle("☑️️X", "☑️X", 404, null), "☑️X");
});
test("decideWriteTitle: 403/5xx (absence NOT confirmed) → keep given title", () => {
  assert.equal(decideWriteTitle("☑️️X", "☑️X", 403, null), "☑️️X");
  assert.equal(decideWriteTitle("☑️️X", "☑️X", 500, null), "☑️️X");
});

test("CAS guard accepts an unchanged base and rejects a concurrent edit", () => {
  const current = ["Page", " body"];
  const strategy = guardPatchStrategy("Page", linesDigest(current), () => ["Page", " changed"]);
  assert.deepEqual(strategy(current), ["Page", " changed"]);
  assert.throws(() => strategy(["Page", " concurrent"]), /concurrent edit detected/);
});

test("CAS guard canonicalizes a not-yet-created page as a title-only page", () => {
  const strategy = guardPatchStrategy("New Page", linesDigest(["New Page"]), () => ["New Page", " body"]);
  assert.deepEqual(strategy([]), ["New Page", " body"]);
});

const boardArgs = (overrides = {}) => ({
  project: "plural-reality",
  title: "ToDoカンバン",
  mode: "replace",
  verbatim: true,
  expectSha256: "a".repeat(64),
  ...overrides,
});

test("GTD boards reject prepend/append and require a CAS-protected verbatim replace", () => {
  const body = "[プロジェクト看板]\n\n[** @PC]";
  assert.equal(validateBoardWrite(boardArgs({ mode: "prepend" }), body).ok, false);
  assert.equal(validateBoardWrite(boardArgs({ mode: "append" }), body).ok, false);
  assert.equal(validateBoardWrite(boardArgs({ verbatim: false }), body).ok, false);
  assert.equal(validateBoardWrite(boardArgs({ expectSha256: undefined }), body).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), body).ok, true);
});

test("GTD boards reject standalone agent progress blocks", () => {
  const report = "[プロジェクト看板]\n[( 調査進捗を記録][codex.icon]";
  const claudeReport = "[プロジェクト看板]\n[( 調査進捗を記録][claude code.icon]";
  const wipReport = "[プロジェクト看板]\n[claude code WIP.icon] 調査進捗";
  const wipChildReport = "[プロジェクト看板]\n [claude code WIP.icon]\n  調査進捗: 3件確認";
  const nestedWipReport = "[プロジェクト看板]\n [claude code WIP.icon]\n  [* wip]\n   調査進捗: 3件確認";
  const structuralQueue = "[プロジェクト看板]\n [claude code WIP.icon]\n  [* todo]\n  [* wip]\n  [* done]";
  const taskQueue = "[プロジェクト看板]\n [claude code WIP.icon]\n  [* todo]\n   [⬜ 明確な次アクション]\n  [* wip]\n   [( [⏳cc: 実行中のタスク]]\n  [* done]\n   [☑️ 完了したタスク]";
  assert.equal(validateBoardWrite(boardArgs(), report).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), claudeReport).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), wipReport).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), wipChildReport).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), nestedWipReport).ok, false);
  assert.equal(validateBoardWrite(boardArgs(), structuralQueue).ok, true);
  assert.equal(validateBoardWrite(boardArgs(), taskQueue).ok, true);
});

test("each GTD board requires a reciprocal link and non-board pages stay unrestricted", () => {
  assert.equal(validateBoardWrite(boardArgs(), "[** @PC]").ok, false);
  assert.equal(validateBoardWrite(boardArgs(), "code:txt\n [プロジェクト看板]").ok, false);
  assert.equal(validateBoardWrite(boardArgs(), "table:links\n [プロジェクト看板]").ok, false);
  assert.equal(
    validateBoardWrite(
      boardArgs({ title: "プロジェクト看板" }),
      "[ToDoカンバン]\n\n[** 進行中]",
    ).ok,
    true,
  );
  assert.equal(
    validateBoardWrite(
      boardArgs({ project: "tkgshn-private", mode: "prepend", verbatim: false, expectSha256: undefined }),
      "自由な本文",
    ).ok,
    true,
  );
});

// Faithful port of the canonical ungray() in tkgshn-extension/llm-auto-humanize: melt every
// gray deco token (chars include '('), keep bare links and non-gray decorations, recurse into
// nested content and the remainder. Used to prove markGrayText round-trips (humanize(grayify(x))===x).
const ungrayRef = (s) => {
  const open = s.indexOf("[");
  const rel = open < 0 ? -1 : matchClose(s.slice(open));
  if (rel < 0) return s;
  const before = s.slice(0, open);
  const token = s.slice(open, open + rel + 1);
  const after = s.slice(open + rel + 1);
  const inner = token.slice(1, -1);
  const sp = inner.indexOf(" ");
  const chars = sp < 0 ? "" : inner.slice(0, sp);
  const content = sp < 0 ? "" : inner.slice(sp + 1);
  const grayDeco = /^[(*\/_-]+$/.test(chars) && chars.includes("(");
  const melted = !grayDeco ? token
    : chars === "(" ? ungrayRef(content)
    : `[${chars.replace("(", "")} ${ungrayRef(content)}]`;
  return before + melted + ungrayRef(after);
};

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

test("mid-line decoration: '(' merges into a deco found ANYWHERE (sibling, not nested)", () => {
  // The regression this fixes: a mid-line [* bold] used to be wrapped whole as
  // "[( 実態は [* X] に変更]", which kills the bold (Scrapbox won't render a deco inside a deco).
  assert.equal(markGrayText("実態は [* X] に変更"), "[( 実態は] [(* X] [( に変更]");
  assert.equal(markGrayText("a [* b] c [/ d] e"), "[( a] [(* b] [( c] [(/ d] [( e]");
  assert.equal(markGrayText("締切は [* 11月]"), "[( 締切は] [(* 11月]");
  assert.notEqual(markGrayText("実態は [* X] に変更"), "[( 実態は [* X] に変更]");
});

test("mid-line decoration round-trips: ungray(markGrayText(x)) === x", () => {
  for (const x of [
    "実態は [* X] に変更",
    "a [* b] c [/ d] e",
    "締切は [* 11月]",
    "関与は [* 紐付け] にシフト。[* もう一つ] も",
    "[Page] 参照",
    "結果 [* 太字] と [Link] と plain",
    "散文だけ",
  ]) {
    assert.equal(ungrayRef(markGrayText(x)), x, `round-trip on ${x}`);
  }
});
