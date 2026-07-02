// Unit tests for the link-rewrite contract in scrapbox-rename.mjs.
// Run: node scrapbox-rename.test.mjs   (pure — no @cosense/std / network needed)
//
// These pin which Scrapbox reference forms a rename repoints, and — just as
// important — which look-alikes it must leave alone (a longer-titled page, an
// external-link label, a dotted sibling page). The deep-link case is the one the
// REST replaceLinks endpoint ignores, so it is the reason this sweep exists.

import assert from "node:assert/strict";
import test from "node:test";
import { rewriteLinks } from "./scrapbox-rename.mjs";

// A real-world MTG title: contains spaces, so it can never be a #hashtag.
const OLD = "⏳2026/6/11 15:00~ 山岡さんMTG";
const NEW = "☑️2026/6/11 15:00~ 山岡さんMTG";

test("plain bracket link is repointed", () => {
  assert.equal(rewriteLinks(`参照: [${OLD}] を見て`, OLD, NEW), `参照: [${NEW}] を見て`);
});

test("deep link keeps its (rename-stable) line anchor", () => {
  const anchor = "5f3ad2c0e1b2a30000111222";
  assert.equal(rewriteLinks(`[${OLD}#${anchor}]`, OLD, NEW), `[${NEW}#${anchor}]`);
});

test("multiple references on one line all move", () => {
  assert.equal(
    rewriteLinks(`[${OLD}] then [${OLD}#abc] again`, OLD, NEW),
    `[${NEW}] then [${NEW}#abc] again`,
  );
});

// ── single-token title (person/entity page): icon + hashtag forms ──
const P_OLD = "山岡さん";
const P_NEW = "山岡先生";

test("icon embed is repointed, including the *N multiplier", () => {
  assert.equal(rewriteLinks(`[${P_OLD}.icon]`, P_OLD, P_NEW), `[${P_NEW}.icon]`);
  assert.equal(rewriteLinks(`[${P_OLD}.icon*3]`, P_OLD, P_NEW), `[${P_NEW}.icon*3]`);
});

test("hashtag link is repointed when bounded by whitespace/EOL", () => {
  assert.equal(rewriteLinks(`#${P_OLD} と会った`, P_OLD, P_NEW), `#${P_NEW} と会った`);
  assert.equal(rewriteLinks(`末尾タグ #${P_OLD}`, P_OLD, P_NEW), `末尾タグ #${P_NEW}`);
});

// ── false-positive guards: look-alikes that MUST stay untouched ──
test("a longer-titled different page is left intact", () => {
  // [山岡さんMTG] is its own page, not a reference to 山岡さん
  assert.equal(rewriteLinks(`[${P_OLD}MTG]`, P_OLD, P_NEW), `[${P_OLD}MTG]`);
});

test("an external link whose label equals the title is left intact", () => {
  const s = `[${P_OLD} https://example.com]`;
  assert.equal(rewriteLinks(s, P_OLD, P_NEW), s);
});

test("a dotted sibling page (not .icon) is left intact", () => {
  const s = `[${P_OLD}.bar]`; // page "山岡さん.bar", not the icon embed
  assert.equal(rewriteLinks(s, P_OLD, P_NEW), s);
});

test("a hashtag that only prefixes a longer tag is left intact", () => {
  assert.equal(rewriteLinks(`#${P_OLD}MTG`, P_OLD, P_NEW), `#${P_OLD}MTG`);
});

test("a bare textual mention (no bracket/hash) is left intact", () => {
  assert.equal(rewriteLinks(`${P_OLD}について書く`, P_OLD, P_NEW), `${P_OLD}について書く`);
});

// ── robustness ──
test("titles with regex-special chars are matched literally", () => {
  const o = "C++ (2026)";
  const n = "C++ (2027)";
  assert.equal(rewriteLinks(`[${o}] と [${o}#x]`, o, n), `[${n}] と [${n}#x]`);
});

test("a newTitle containing $ is substituted verbatim (no backreference)", () => {
  assert.equal(rewriteLinks("[A] #A", "A", "B$1C"), "[B$1C] #B$1C");
});

test("rewriting an already-renamed body is a no-op (idempotent)", () => {
  const body = `[${NEW}] [${NEW}#abc]`;
  assert.equal(rewriteLinks(body, OLD, NEW), body);
  // applying twice is stable
  assert.equal(rewriteLinks(rewriteLinks(body, OLD, NEW), OLD, NEW), body);
});

test("multiple hashtags across lines all move", () => {
  assert.equal(
    rewriteLinks(`#${P_OLD}\nfoo #${P_OLD} bar`, P_OLD, P_NEW),
    `#${P_NEW}\nfoo #${P_NEW} bar`,
  );
});
