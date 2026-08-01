import assert from "node:assert/strict";
import test from "node:test";
import { classifyNote, noteHash, pageTitle, planWrite, PRIVATE_PROJECT, TAKALOG_PROJECT } from "./apple-notes-to-scrapbox.mjs";

const baseNote = {
  account: "iCloud",
  folder: "Scrapbox Sync",
  id: "x-coredata://example",
  title: "読書メモ",
  modified: "Sun Jul 05 2026 20:00:00 GMT+0900",
  plaintext: "分散システムのメモ。あとで読み返す。",
  attachmentCount: 0,
};

test("safe personal note routes to tkgshn-private", () => {
  const classified = classifyNote(baseNote);
  assert.equal(classified.classification.project, PRIVATE_PROJECT);
  assert.equal(classified.classification.blocked, false);
});

test("email and person context routes to takalog", () => {
  const classified = classifyNote({
    ...baseNote,
    title: "山田さんに返信",
    plaintext: "yamada@example.com にフォローアップする",
  });
  assert.equal(classified.classification.project, TAKALOG_PROJECT);
  assert.equal(classified.classification.blocked, false);
  assert.ok(classified.classification.reasons.includes("email"));
});

test("auth secrets are blocked and routed to takalog review", () => {
  const classified = classifyNote({
    ...baseNote,
    title: "API key",
    plaintext: "OPENAI_API_KEY=secret",
  });
  const plan = planWrite(classified);
  assert.equal(classified.classification.project, TAKALOG_PROJECT);
  assert.equal(classified.classification.blocked, true);
  assert.ok(plan.title.startsWith("[Appleメモ:要手動確認]"));
  assert.match(plan.body, /本文は自動転記しない/);
  assert.doesNotMatch(plan.body, /OPENAI_API_KEY=secret/);
});

test("attachments are blocked because OCR text is not inspected", () => {
  const classified = classifyNote({ ...baseNote, attachmentCount: 1 });
  assert.equal(classified.classification.project, TAKALOG_PROJECT);
  assert.equal(classified.classification.blocked, true);
  assert.ok(classified.classification.reasons.includes("attachment-unread"));
});

test("page title includes stable source key and hash marker is rendered", () => {
  const classified = classifyNote(baseNote);
  const plan = planWrite(classified);
  assert.match(pageTitle(classified, classified.classification), /^\[Appleメモ\] 読書メモ [0-9a-f]{10}$/);
  assert.match(plan.body, new RegExp(`source-hash: ${noteHash(classified)}`));
});
