// scb-lint の純検知判定のユニットテスト。
// 実行: node scb-lint.test.mjs （失敗時 exit 1）。ネットワーク不要(判定は純関数)。
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  isDatePage,
  isSystemPage,
  isTransactionalPage,
  isLogPage,
  isExcluded,
  normalizeTitle,
  isOrphan,
  isEmptyStub,
  findDuplicates,
  findEmojiVariants,
  stripStatusPrefix,
  detect,
  SEVERITY,
  ORPHAN_MIN_CHARS,
  ORPHAN_MIN_AGE_DAYS,
} from "./scb-lint.mjs";

const T = (name, fn) => {
  try {
    fn();
    console.log("ok  -", name);
  } catch (e) {
    console.error("FAIL-", name, "\n", e.message);
    process.exitCode = 1;
  }
};

const NOW = 1_800_000_000; // 固定 now(秒)
const OLD = NOW - (ORPHAN_MIN_AGE_DAYS + 5) * 86400; // 十分古い
const NEW = NOW - 3 * 86400; // 新しすぎ

// --- isDatePage ---
T("date page detected", () => assert.equal(isDatePage("2026/6/25"), true));
T("date page with suffix detected", () => assert.equal(isDatePage("2026/06/25 日報"), true));
T("hyphen date page detected (email index)", () => assert.equal(isDatePage("2026-04-09 Re: ご挨拶"), true));
T("non-date title", () => assert.equal(isDatePage("LLM"), false));

// --- isLogPage (自動生成/ログ/メール転記/貼付け) ---
T("email reply chain is log", () => assert.equal(isLogPage("Re: 地域活性化起業人に係る申請等について"), true));
T("external mail marker is log", () =>
  assert.equal(isLogPage("2026-04-08 【External】Re: ご挨拶 - 高木俊輔"), true));
T("mail message-id hash suffix is log", () =>
  assert.equal(isLogPage("2026-04-09 Re: ご挨拶 - 秋葉杏介 (5e4973)"), true));
T("crawl-result log is log", () => assert.equal(isLogPage("官公需クローリング結果（2026/6/8）"), true));
T("thought-log dump is log", () => assert.equal(isLogPage("akiba思考ログ/2026/4/25"), true));
T("hierarchical date sublog is log", () => assert.equal(isLogPage("foo/2026/4/25"), true));
T("url-titled paste is log", () => assert.equal(isLogPage("https://cosense-context-proxy.vercel.app/r/abc"), true));
T("code-fence paste is log", () => assert.equal(isLogPage("```Last login: Tue May 12"), true));
T("ordinary knowledge title is NOT log", () => assert.equal(isLogPage("動的合意形成"), false));
T("ordinary person title is NOT log", () => assert.equal(isLogPage("遠藤貴幸"), false));

// --- isExcluded: ハイフン日付メール索引は日付ページ扱いで全タイプ除外 / 実知識ページは通す ---
T("isExcluded covers hyphen-date email index", () =>
  assert.equal(isExcluded("2026-04-09 Re: ご挨拶 - 高木俊輔 (b0bf9c)"), true));
T("isExcluded lets real knowledge page through", () => assert.equal(isExcluded("動的合意形成"), false));
// duplicate/empty-stub は貼付け事故(コードフェンス題)も統合候補として拾うため isExcluded しない
T("isExcluded does NOT drop code-fence paste page (still dedupable)", () =>
  assert.equal(isExcluded("```次の100年のための統治技術"), false));

// --- isSystemPage ---
T("icon page is system", () => assert.equal(isSystemPage("tkgshn.icon"), true));
T("README is system", () => assert.equal(isSystemPage("README"), true));
T("Lint queue itself is system", () => assert.equal(isSystemPage("Scrapbox Lint"), true));
T("ordinary page not system", () => assert.equal(isSystemPage("Futarchy"), false));

// --- isTransactionalPage (status/marker prefix) ---
T("done-check prefix is transactional", () => assert.equal(isTransactionalPage("☑️本店移転 完了"), true));
T("checkbox prefix is transactional", () => assert.equal(isTransactionalPage("⬜ 税理士アサイン(最優先)"), true));
T("in-progress prefix is transactional", () => assert.equal(isTransactionalPage("⏳個別ページ化"), true));
T("comment prefix is transactional", () => assert.equal(isTransactionalPage("💬 雑談ログ"), true));
T("ordinary title not transactional", () => assert.equal(isTransactionalPage("松竹梅メソッド"), false));

// --- normalizeTitle ---
T("full/half width unified", () => assert.equal(normalizeTitle("ＬＬＭ"), "llm"));
T("space and punct stripped", () => assert.equal(normalizeTitle("LLM Wiki!"), "llmwiki"));
T("japanese punct stripped", () => assert.equal(normalizeTitle("多元・現実"), "多元現実"));

// --- isOrphan ---
const orphan = { title: "孤立した良ページ", linked: 0, pin: 0, charsCount: 500, created: OLD };
T("orphan: linked0 + content + old", () => assert.equal(isOrphan(orphan, NOW), true));
T("orphan: linked>0 is not orphan", () => assert.equal(isOrphan({ ...orphan, linked: 1 }, NOW), false));
T("orphan: pinned is not orphan", () => assert.equal(isOrphan({ ...orphan, pin: 1 }, NOW), false));
T("orphan: too short is not orphan", () =>
  assert.equal(isOrphan({ ...orphan, charsCount: ORPHAN_MIN_CHARS - 1 }, NOW), false));
T("orphan: too new is not orphan", () => assert.equal(isOrphan({ ...orphan, created: NEW }, NOW), false));
T("orphan: date page excluded", () => assert.equal(isOrphan({ ...orphan, title: "2026/6/1" }, NOW), false));
T("orphan: transactional (☑️) excluded", () =>
  assert.equal(isOrphan({ ...orphan, title: "☑️音威子府村への返信" }, NOW), false));
T("orphan: auto-generated log (crawl result) excluded", () =>
  assert.equal(isOrphan({ ...orphan, title: "官公需クローリング結果（2026/6/8）" }, NOW), false));
T("orphan: url-titled paste log excluded", () =>
  assert.equal(isOrphan({ ...orphan, title: "https://scrapbox.io/foo/bar" }, NOW), false));

// --- isEmptyStub ---
const stub = { title: "未記述の概念", linesCount: 1, linked: 5, pin: 0 };
T("empty-stub: empty body + many backlinks", () => assert.equal(isEmptyStub(stub), true));
T("empty-stub: has body is not stub", () => assert.equal(isEmptyStub({ ...stub, linesCount: 10 }), false));
T("empty-stub: few backlinks is not stub", () => assert.equal(isEmptyStub({ ...stub, linked: 2 }), false));
T("empty-stub: checkbox task excluded", () =>
  assert.equal(isEmptyStub({ ...stub, title: "⬜ 税理士アサイン(最優先)" }), false));

// --- findDuplicates ---
T("duplicate: case/space-insensitive collision", () => {
  const g = findDuplicates([{ title: "Futarchy" }, { title: "futarchy" }, { title: "LLM" }]);
  assert.equal(g.length, 1);
  assert.deepEqual(g[0].titles.sort(), ["Futarchy", "futarchy"]);
});
T("duplicate: no false positive on distinct titles", () =>
  assert.equal(findDuplicates([{ title: "A" }, { title: "B" }]).length, 0));
T("duplicate: date pages not deduped", () =>
  assert.equal(findDuplicates([{ title: "2026/6/1" }, { title: "2026/6/1 " }]).length, 0));

// --- detect (統合) ---
T("detect: mixes types and stamps fingerprint/url (plural-reality)", () => {
  const pages = [
    { title: "孤立した良ページ", linked: 0, pin: 0, charsCount: 500, created: OLD, updated: OLD },
    { title: "未記述の概念", linesCount: 1, linked: 5, pin: 0 },
  ];
  const fs = detect("plural-reality", pages, NOW);
  const types = fs.map((f) => f.type).sort();
  assert.deepEqual(types, ["empty-stub", "orphan"]);
  assert.ok(fs.every((f) => f.fingerprint.startsWith(f.type + "|plural-reality|")));
  assert.ok(fs.every((f) => f.url.startsWith("https://scrapbox.io/plural-reality/")));
  assert.ok(fs.every((f) => f.question.includes("？")));
});

// --- orphan scope: ORPHAN_PROJECTS 以外では orphan を出さない(ログ主体の project のノイズ抑制) ---
T("detect: orphan suppressed outside ORPHAN_PROJECTS", () => {
  const pages = [
    { title: "孤立した良ページ", linked: 0, pin: 0, charsCount: 500, created: OLD, updated: OLD },
    { title: "未記述の概念", linesCount: 1, linked: 5, pin: 0 },
  ];
  const fsPriv = detect("tkgshn-private", pages, NOW).map((f) => f.type).sort();
  const fsLog = detect("takalog", pages, NOW).map((f) => f.type).sort();
  // empty-stub は全 project で出るが、orphan は plural-reality 以外では出ない
  assert.deepEqual(fsPriv, ["empty-stub"]);
  assert.deepEqual(fsLog, ["empty-stub"]);
});

// --- emoji-variant: 状態絵文字/VS16/cc: だけ違う二重ページ検出 ---
T("emoji-variant: status-emoji / VS16 / cc: variants of one base title group together", () => {
  const pages = [
    { title: "⬜ 音威子府の企業人名義を切り替える" },
    { title: "☑️ 音威子府の企業人名義を切り替える" },
    { title: "⏳cc: 広報誌9月号で特集紹介する" },
    { title: "☑️広報誌9月号で特集紹介する" },
    { title: "絵文字なし単独ページ" },
    { title: "⏹️単独タスク" },
  ];
  const groups = findEmojiVariants(pages);
  assert.equal(groups.length, 2);
  assert.deepEqual(groups.map((g) => g.titles.length), [2, 2]);
});

T("emoji-variant: VS16-only difference is a variant pair", () => {
  const one = "☑️高木インド出張"; // ☑️ (VS16x1)
  const two = "☑️️高木インド出張"; // ☑️️ (VS16x2)
  assert.equal(findEmojiVariants([{ title: one }, { title: two }]).length, 1);
});

T("stripStatusPrefix: strips emoji chain, VS16 residue, and cc: marker", () => {
  assert.equal(stripStatusPrefix("⏳cc: タスクA"), "タスクA");
  assert.equal(stripStatusPrefix("️構想日本と共に勉強会"), "構想日本と共に勉強会");
  assert.equal(stripStatusPrefix("絵文字なし"), "絵文字なし");
});

T("emoji-variant: non-status emoji VS16 (©️) is NOT grouped as a variant", () => {
  assert.equal(findEmojiVariants([{ title: "©️ Policy" }, { title: "©️️ Policy" }]).length, 0);
});

T("emoji-variant: prototype-name titles ('constructor') do not crash grouping", () => {
  const groups = findEmojiVariants([{ title: "⬜ constructor" }, { title: "☑️ constructor" }]);
  assert.equal(groups.length, 1);
  assert.equal(findDuplicates([{ title: "constructor" }, { title: "Constructor" }]).length, 1);
});

T("detect: emoji-variant finding carries severity=file", () => {
  const pages = [{ title: "⬜ 名義切替" }, { title: "☑️ 名義切替" }];
  const found = detect("plural-reality", pages, NOW).filter((f) => f.type === "emoji-variant");
  assert.equal(found.length, 1);
  assert.equal(found[0].severity, "file");
});

// --- severity policy: stub/duplicate=file, orphan=digest ---
T("severity: stub and duplicate are fileable, orphan is digest-only", () => {
  assert.equal(SEVERITY["empty-stub"], "file");
  assert.equal(SEVERITY["duplicate"], "file");
  assert.equal(SEVERITY["orphan"], "digest");
  const pages = [{ title: "未記述の概念", linesCount: 1, linked: 5, pin: 0 }];
  assert.equal(detect("takalog", pages, NOW)[0].severity, "file");
});

// CLI tests use a local fake cosense-fetch; no network/auth or Scrapbox writes.
const runCli = (responses, args = ["--json", ...Object.keys(responses)]) => {
  const dir = mkdtempSync(join(tmpdir(), "scb-lint-test-"));
  try {
    const fake = `#!/usr/bin/env node
const fs = require("node:fs");
const args = process.argv.slice(2);
const response = ${JSON.stringify(responses)}[args[args.indexOf("-p") + 1]];
if (response.body !== undefined) fs.writeFileSync(args[args.indexOf("-o") + 1], response.body);
process.exit(response.exitCode || 0);
`;
    writeFileSync(join(dir, "cosense-fetch"), fake, { mode: 0o755 });
    return spawnSync(process.execPath, [fileURLToPath(new URL("./scb-lint.mjs", import.meta.url)), ...args], {
      encoding: "utf8",
      env: { ...process.env, PATH: `${dir}${delimiter}${process.env.PATH || ""}` },
      timeout: 10_000,
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};
const listedPage = (page) => ({ linked: 0, pin: 0, charsCount: 0, linesCount: 1, created: OLD, updated: OLD, ...page });
const response = (pages, count = pages.length) => ({ body: JSON.stringify({ pages, count }) });

T("CLI: child failure rejects even a plausible output file", () => {
  const result = runCli({ takalog: { ...response([]), exitCode: 7 } });
  assert.equal(result.status, 1);
  const report = JSON.parse(result.stdout);
  assert.equal(report.status, "failed");
  assert.equal(report.coverage[0].status, "failed");
  assert.equal(report.coverage[0].total, null);
  assert.deepEqual(report.findings, []);
});
T("CLI: unreadable output is failure, not healthy empty project", () => {
  const result = runCli({ takalog: {} });
  assert.equal(result.status, 1);
  assert.equal(JSON.parse(result.stdout).status, "failed");
});
T("CLI: malformed JSON, schema and page metadata fail closed", () => {
  const bodies = ["not json", "null", "{}", '{"pages":[]}', '{"count":-1,"pages":[]}',
    '{"count":0,"pages":[{"title":"A"}]}', '{"count":1,"pages":[null]}',
    '{"count":1,"pages":[{"title":3}]}', '{"count":1,"pages":[{"title":"A","linked":"0"}]}'];
  for (const body of bodies) {
    const result = runCli({ takalog: { body } });
    assert.equal(result.status, 1, body);
    assert.equal(JSON.parse(result.stdout).status, "failed", body);
  }
});
T("CLI: missing detection metadata never implies healthy or empty-stub", () => {
  const full = listedPage({ title: "A" });
  const missingFields = ["linked", "pin", "charsCount", "linesCount", "created", "updated"];
  const pages = [{ title: "A" }, { title: "A", linked: 3 },
    ...missingFields.map((key) => Object.fromEntries(Object.entries(full).filter(([field]) => field !== key)))];
  for (const page of pages) {
    const result = runCli({ takalog: response([page]) });
    assert.equal(result.status, 1, JSON.stringify(page));
    const report = JSON.parse(result.stdout);
    assert.equal(report.status, "failed");
    assert.deepEqual(report.findings, []);
  }
});
T("CLI: genuinely empty successful project is complete", () => {
  const result = runCli({ takalog: response([]) });
  assert.equal(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.status, "complete");
  assert.deepEqual(report.findings, []);
  assert.equal(report.coverage[0].total, 0);
  assert.equal(report.coverage[0].scanned, 0);
});
T("CLI: mixed fetch outcome preserves findings with partial coverage and failure exit", () => {
  const result = runCli({ takalog: { exitCode: 22 }, "plural-reality": response([listedPage(stub)]) });
  assert.equal(result.status, 1);
  const report = JSON.parse(result.stdout);
  assert.equal(report.status, "partial");
  assert.equal(report.findings.length, 1);
  assert.equal(report.findings[0].type, "empty-stub");
  assert.deepEqual(report.coverage.map((c) => c.status), ["failed", "complete"]);
});
T("CLI: latest-1000 bound is explicit in JSON coverage", () => {
  const pages = Array.from({ length: 1000 }, (_, i) => listedPage({ title: `page${i}`, linesCount: 2, linked: 1 }));
  const result = runCli({ takalog: response(pages, 4542) });
  assert.equal(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.status, "partial");
  assert.equal(report.coverage[0].scanned, 1000);
  assert.equal(report.coverage[0].total, 4542);
  assert.equal(report.coverage[0].limit, 1000);
  assert.equal(report.coverage[0].scope, "latest-updated");
  assert.match(result.stderr, /partial/);
});
T("CLI: unexpected empty subset does not claim a complete scan", () => {
  const result = runCli({ takalog: response([], 3) });
  assert.equal(result.status, 0);
  assert.equal(JSON.parse(result.stdout).status, "partial");
});
T("CLI: failed human report does not say findings absent", () => {
  const result = runCli({ takalog: { exitCode: 22 } }, ["takalog"]);
  assert.equal(result.status, 1);
  assert.match(result.stdout, /failed/);
  assert.doesNotMatch(result.stdout, /機械的 findings なし/);
});

if (process.exitCode) console.error("\nSOME TESTS FAILED");
else console.log("\nall scb-lint tests passed");
