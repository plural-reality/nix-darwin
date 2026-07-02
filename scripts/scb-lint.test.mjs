// scb-lint の純検知判定のユニットテスト。
// 実行: node scb-lint.test.mjs （失敗時 exit 1）。ネットワーク不要(判定は純関数)。
import assert from "node:assert/strict";
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

// --- severity policy: stub/duplicate=file, orphan=digest ---
T("severity: stub and duplicate are fileable, orphan is digest-only", () => {
  assert.equal(SEVERITY["empty-stub"], "file");
  assert.equal(SEVERITY["duplicate"], "file");
  assert.equal(SEVERITY["orphan"], "digest");
  const pages = [{ title: "未記述の概念", linesCount: 1, linked: 5, pin: 0 }];
  assert.equal(detect("takalog", pages, NOW)[0].severity, "file");
});

if (process.exitCode) console.error("\nSOME TESTS FAILED");
else console.log("\nall scb-lint tests passed");
