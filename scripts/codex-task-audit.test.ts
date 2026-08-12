import assert from "node:assert/strict";
import test from "node:test";

import {
  auditThreads,
  decodeThreads,
  normalizeObjective,
  parseArgs,
  renderMarkdown,
} from "./codex-task-audit.ts";

const hour = 60 * 60;
const now = 2_000_000;

const thread = (
  id: string,
  title: string,
  overrides: Readonly<Record<string, unknown>> = {},
): Readonly<Record<string, unknown>> => ({
  id,
  title,
  cwd: "/work/repo",
  archived: false,
  createdAt: now - hour,
  recencyAt: now - hour,
  mode: "general",
  ...overrides,
});

test("normalizes status, compatibility prefix, width and punctuation", () =>
  assert.equal(normalizeObjective("⌛️ cc: Ｒｅｖｉｅｗ  current-code_changes!!"), "review current code changes"),
);

test("reports only close duplicate candidates and excludes scheduled repetitions", () => {
  const decoded = decodeThreads([
    thread("a", "⌛️ Review current code changes", { createdAt: now - 3 * hour }),
    thread("b", "⌛️ review current-code changes", { createdAt: now - 2 * hour }),
    thread("c", "⌛️ Review current code changes", {
      cwd: "/work/other",
      createdAt: now - hour,
    }),
    thread("d", "⌛️ 日報を作る", { mode: "scheduled", createdAt: now - 3 * hour }),
    thread("e", "⌛️ 日報を作る", { mode: "scheduled", createdAt: now - 2 * hour }),
    thread("scheduled-stale", "⌛️ 日報を作る", {
      mode: "scheduled",
      recencyAt: now - 49 * hour,
    }),
    thread("special-a", "⌛️ 特殊キー", { cwd: "__proto__", createdAt: now - 2 * hour }),
    thread("special-b", "⌛️ 特殊キー", { cwd: "__proto__", createdAt: now - hour }),
    thread("recent", "⌛️ 古い同名が混ざる", { createdAt: now }),
    thread("near", "⌛️ 古い同名が混ざる", { createdAt: now - 23 * hour }),
    thread("older", "⌛️ 古い同名が混ざる", { createdAt: now - 25 * hour }),
    thread("old", "状態のない古いタスク", { recencyAt: now - 40 * 24 * hour }),
  ]);
  const report = decoded.ok
    ? auditThreads(decoded.value, {
        now,
        duplicateWindowHours: 24,
        staleHours: 48,
        lookbackDays: 35,
        limit: 20,
      })
    : assert.fail(decoded.error);
  const kinds = report.findings.map(({ kind }) => kind);

  assert.equal(kinds.filter((kind) => kind === "duplicate_exact").length, 3);
  assert.equal(kinds.filter((kind) => kind === "duplicate_objective").length, 1);
  assert.equal(report.findings.some(({ title }) => title.includes("日報")), false);
  assert.equal(report.findings.some(({ ids }) => ids.includes("old")), false);
  assert.equal(report.findings.some(({ ids }) => ids.includes("special-a")), true);
  assert.equal(
    report.findings.some(({ ids }) => ids.includes("recent") && ids.includes("near")),
    true,
  );
});

test("separates human-wait, stale-working, archive and missing-status candidates", () => {
  const decoded = decodeThreads([
    thread("human", "⌛️ 本人の認証待ち", { recencyAt: now - hour }),
    thread("stale", "⌛️ 調査を継続", { recencyAt: now - 49 * hour }),
    thread("done", "☑️ 調査を完了", { recencyAt: now - hour }),
    thread("stopped", "⏹️ 調査を停止", { recencyAt: now - hour }),
    thread("untitled", "調査する", { recencyAt: now - hour }),
    thread("short-title", "form", { recencyAt: now - hour }),
    thread("external", "⌛️ 調整（区議の返信待ち）", { recencyAt: now - 49 * hour }),
  ]);
  const report = decoded.ok
    ? auditThreads(decoded.value, {
        now,
        duplicateWindowHours: 24,
        staleHours: 48,
        lookbackDays: 35,
        limit: 20,
      })
    : assert.fail(decoded.error);
  const byId = Object.fromEntries(report.findings.map((finding) => [finding.ids[0], finding.kind]));

  assert.equal(byId.human, "human_wait_status");
  assert.equal(byId.stale, "stale_working");
  assert.equal(byId.done, "archive_candidate");
  assert.equal(byId.stopped, "archive_candidate");
  assert.equal(byId.untitled, "missing_status");
  assert.equal(byId["short-title"], "missing_status");
  assert.equal(Object.hasOwn(byId, "external"), false);
});

test("rejects malformed input and renders a bounded Japanese review", () => {
  assert.deepEqual(decodeThreads({}), {
    ok: false,
    error: "input must be a JSON array",
  });
  assert.deepEqual(decodeThreads([{ id: "a" }]), {
    ok: false,
    error: "threads[0].title must be a non-empty string",
  });

  const decoded = decodeThreads([
    thread("done", "☑️ 完了A"),
    thread("done-2", "☑️ 完了B"),
  ]);
  const markdown = decoded.ok
    ? renderMarkdown(auditThreads(decoded.value, {
        now,
        duplicateWindowHours: 24,
        staleHours: 48,
        lookbackDays: 35,
        limit: 1,
      }))
    : assert.fail(decoded.error);

  assert.match(markdown, /Codexタスク・ライフサイクル監査/);
  assert.match(markdown, /候補: 2件（表示 1件 \/ 上限 1件）/);
  assert.equal((markdown.match(/^### /gm) ?? []).length, 1);
});

test("rejects a fractional output limit", () =>
  assert.deepEqual(
    [parseArgs(["--limit", "0.5"]), parseArgs(["--unknown"])],
    [
      { ok: false, error: "--limit must be a positive integer" },
      { ok: false, error: "unknown argument: --unknown" },
    ],
  ),
);
