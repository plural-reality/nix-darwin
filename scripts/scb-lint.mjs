#!/usr/bin/env node
// scb-lint — Scrapbox 3 project の「機械的 Lint」純検知フィルタ。
//
// Karpathy の LLM Wiki の Lint(=定期健全性チェック)のうち、deterministic に出せる機械的観点だけを担う。
// 意味的観点(矛盾 / stale claim / 概念ページ不足 / 新質問提案)は /scb-lint skill 側の LLM パスが担当する。
// source of truth は Scrapbox 自身。状態(filing 済みか)は skill 側の seen.json が持ち、本ファイルは純検知のみ。
//
// 入力: project 名(args、既定 3 project) / 出力: findings 一覧(既定=表 / --json=JSON)
// 依存: cosense-fetch(--list で各 project のページ一覧メタを取る。linked=被リンク数, linesCount, charsCount, pin, created)。
//
// 機械的検知タイプ:
//   orphan      … 実質コンテンツのある persistent ページが被リンク 0(=どこからも参照されない孤立ページ)。
//   duplicate   … 正規化タイトルが衝突する複数ページ(同一 project 内・統合候補)。
//   empty-stub  … linesCount<=1(タイトルのみで本体が空)だが被リンク>=N(=参照されてるのに未記述の概念ページ)。
//
// ponytail: 機械的スキャンは `cosense-fetch --list -l LIMIT`(更新降順)で最新 LIMIT 件/project を対象にする。
//   それより古い tail は対象外(cosense-fetch が skip ページングを公開していないため)。上限到達は log に出す。
//   将来 cosense-fetch に skip を足すか直 API でページングすれば全件化できる(=upgrade path)。

import { execFile } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const PROJECTS_DEFAULT = ["plural-reality", "tkgshn-private", "takalog"];

// orphan(孤立ページ)検知を有効にする project。
//   ponytail: tkgshn-private / takalog は claude 会話ログ・自動取込ログ・URL題の貼付けページが多数を占め、
//   それらは本質的に被リンク0で当然(=偽陽性)。メタデータだけでログか知識ページかを判別できないため、
//   キュレーションされた plural-reality にのみ orphan 検知をかける(空スタブ/重複は全 project で精度が高いので据え置き)。
//   upgrade path: cosense-fetch に「2行目が from [claude codeセッション] か」等の content シグナルを足せば
//   ログpage を除外して tkgshn-private / takalog も再有効化できる。
export const ORPHAN_PROJECTS = ["plural-reality"];

// しきい値(調整しやすいよう一箇所に集約)
export const LIMIT = 1000; // --list 取得件数/project
export const ORPHAN_MIN_CHARS = 280; // この文字数以上の孤立ページだけを「繋ぐ価値あり」として拾う
export const ORPHAN_MIN_AGE_DAYS = 21; // 新規ページは繋がる猶予を与えて除外
export const STUB_MAX_LINES = 1; // 本体が空(タイトル行のみ)
export const STUB_MIN_LINKED = 3; // 参照が多い空ページ=概念ページ不足シグナル

const DAY = 86400;

// --- 純粋判定 ---------------------------------------------------------------

// 日付ページ(日報) 2026/6/25 等。スラッシュ区切りに加えハイフン区切り(2026-04-09 …)も日付扱い。
//   メール索引ページが "2026-04-09 Re: …" 形式で orphan 誤検知されていたのを防ぐ。
export const isDatePage = (title) => /^\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}/.test(title);

// 自動生成 / ログ / メール転記 / 貼付けページ: 本質的に leaf(被リンク0で当然)なので orphan にしない。
//   メタデータだけで判別できる範囲の deterministic なパターンのみ(誤除外を避け保守的に)。
export const isLogPage = (title) => {
  const t = title.replace(/^[\s　]+/, "");
  return (
    /(?:^|\s)(?:Re:|RE:|Fwd:|FW:|返信:|転送:)/.test(t) || // メール返信/転送チェーン
    /【External】/.test(t) || // 外部メールマーカー
    /\([0-9a-f]{6}\)\s*$/.test(t) || // "… (b0bf9c)" メール message-id 由来の末尾ハッシュ
    /(?:官公需)?クローリング結果/.test(t) || // 自動クローリング結果ログ
    /思考ログ/.test(t) || // 思考ログのダンプ
    /\/20\d\d\/\d/.test(t) || // 階層的な日付サブログ  foo/2026/4/25
    /^(?:https?:|www\.|```|\/Users|b\/Users|Image[ :#]|Base directory)/.test(t) // URL/コードフェンス/パス/画像題の貼付けログ
  );
};

// システム / index / アイコン / Lint キュー自身 など、孤立して当然のページ
export const isSystemPage = (title) =>
  title.includes(".icon") ||
  title === "Scrapbox Lint" ||
  title === "Untitled" ||
  /^(settings|README|index|_)/i.test(title) ||
  title.startsWith("/");

// 取引/タスク/会話マーカー始まりのページ(完了タスク☑️ / チェックボックス⬜✅ / 進行中⏳ / ドラフト🔖 / コメント💬 等)。
// これらは「育てる知識ページ」ではなくワークフロー成果物なので Lint 対象から外す(ノイズ源)。
export const isTransactionalPage = (title) =>
  /^[\s　]*[☑✅⬜⬛⏹⏳🔖🔲💬▶◀🟢🔴🟡⚠✔❌🆕📌🗑🚧⭕]/u.test(title);

// 全 Lint タイプ共通の除外(日付ページ / システム / 取引・タスクページ)。
//   isLogPage は orphan 専用(下記 isOrphan)で使う。duplicate/empty-stub は貼付け事故ページも
//   統合候補として拾う価値があるため、ここには含めない(=既存挙動を保つ)。
export const isExcluded = (title) => isDatePage(title) || isSystemPage(title) || isTransactionalPage(title);

// タイトル正規化(重複検出用): NFKC で全角半角統一 → 小文字 → 空白・記号除去
export const normalizeTitle = (title) =>
  title
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[\s　]+/g, "")
    .replace(/[!-/:-@[-`{-~、。「」（）・…ー－—]/g, "");

// 1ページが orphan か(被リンク0・本体あり・新規/日付/pin/system/取引/自動生成ログ 除外)
//   自動生成ログ(isLogPage)は本質的に被リンク0で当然なので orphan から外す(orphan 専用の除外)。
export const isOrphan = (page, nowSec) => {
  const ageOk = nowSec - (page.created || 0) > ORPHAN_MIN_AGE_DAYS * DAY;
  return (
    (page.linked || 0) === 0 &&
    (page.pin || 0) === 0 &&
    (page.charsCount || 0) >= ORPHAN_MIN_CHARS &&
    ageOk &&
    !isExcluded(page.title) &&
    !isLogPage(page.title)
  );
};

// 1ページが empty-stub(参照されてるのに未記述の概念ページ)か
export const isEmptyStub = (page) =>
  (page.linesCount || 0) <= STUB_MAX_LINES &&
  (page.linked || 0) >= STUB_MIN_LINKED &&
  (page.pin || 0) === 0 &&
  !isExcluded(page.title);

// 同一 project 内の重複タイトル群を返す [{ norm, titles:[...] }]
export const findDuplicates = (pages) => {
  const groups = pages
    .filter((p) => !isExcluded(p.title))
    .reduce((acc, p) => {
      const k = normalizeTitle(p.title);
      return k ? { ...acc, [k]: [...(acc[k] || []), p.title] } : acc;
    }, {});
  return Object.entries(groups)
    .map(([norm, titles]) => ({ norm, titles: [...new Set(titles)] }))
    .filter((g) => g.titles.length > 1);
};

const sbUrl = (project, title) =>
  `https://scrapbox.io/${project}/${encodeURIComponent(title.replace(/ /g, "_"))}`;

// 検知タイプごとの扱い: file=高精度なので WIP 問いとして自動 filing / digest=ノイズ多なのでレポート止まり(人間レビュー)
export const SEVERITY = { "empty-stub": "file", duplicate: "file", orphan: "digest" };

// finding 1件を組み立てる。fingerprint は seen.json での dedup キー(type|project|subject)。
const mkFinding = (type, project, subject, question, signal) => ({
  type,
  severity: SEVERITY[type] || "digest",
  project,
  subject,
  fingerprint: `${type}|${project}|${normalizeTitle(subject)}`,
  question,
  url: sbUrl(project, subject),
  signal,
});

// 1 project のページ一覧 → 機械的 findings
export const detect = (project, pages, nowSec) => {
  // orphan は ORPHAN_PROJECTS(=plural-reality)でのみ検知(ログ主体の他 project はノイズ源)。
  const orphans = (ORPHAN_PROJECTS.includes(project) ? pages : [])
    .filter((p) => isOrphan(p, nowSec))
    .map((p) =>
      mkFinding(
        "orphan",
        project,
        p.title,
        `「${p.title}」はどこからも参照されていない孤立ページ。どのページから繋ぐべき？ あるいは統合 / アーカイブすべき？`,
        { linked: p.linked, charsCount: p.charsCount, updated: p.updated }
      )
    );
  const stubs = pages
    .filter(isEmptyStub)
    .map((p) =>
      mkFinding(
        "empty-stub",
        project,
        p.title,
        `「${p.title}」は ${p.linked} ページから参照されているが本体が空。概念ページとして書くべき内容は？`,
        { linked: p.linked, linesCount: p.linesCount }
      )
    );
  const dups = findDuplicates(pages).map((g) =>
    mkFinding(
      "duplicate",
      project,
      g.titles.join(" / "),
      `「${g.titles.join("」「")}」は重複の疑い。統合すべき？ どれを正本にする？`,
      { titles: g.titles }
    )
  );
  return [...orphans, ...stubs, ...dups];
};

// --- IO 境界 ----------------------------------------------------------------

const runFile = (cmd, cmdArgs) =>
  new Promise((resolve) =>
    execFile(
      cmd,
      cmdArgs,
      { maxBuffer: 128 * 1024 * 1024, env: { ...process.env, LANG: "ja_JP.UTF-8", LC_ALL: "ja_JP.UTF-8" } },
      () => resolve()
    )
  );

const parseJson = (s) => {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
};

// cosense-fetch --list は JSON を「実ファイル」にしか書かない(stdout/-o /dev/stdout はテーブル)。
// よって ephemeral な temp file 経由で JSON を受け、必ず unlink する(内部処理限定の一時領域)。
const listPages = async (project) => {
  const dir = mkdtempSync(join(tmpdir(), "scb-lint-"));
  const out = join(dir, "list.json");
  try {
    await runFile("cosense-fetch", ["--list", "-p", project, "-l", String(LIMIT), "-o", out]);
    const d = parseJson(readFileSync(out, "utf8"));
    return d && Array.isArray(d.pages) ? d : { pages: [], count: 0 };
  } catch {
    return { pages: [], count: 0 };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
};

const crawl = async (projects, nowSec) => {
  const perProject = await Promise.all(
    projects.map(async (p) => {
      const lj = await listPages(p);
      const pages = Array.isArray(lj.pages) ? lj.pages : [];
      const total = typeof lj.count === "number" ? lj.count : pages.length;
      const capped = total > pages.length ? { project: p, scanned: pages.length, total } : null;
      return { findings: detect(p, pages, nowSec), capped };
    })
  );
  return {
    findings: perProject.flatMap((x) => x.findings),
    capped: perProject.map((x) => x.capped).filter(Boolean),
  };
};

const main = async () => {
  const args = process.argv.slice(2);
  const asJson = args.includes("--json");
  const projects = args.filter((a) => !a.startsWith("--"));
  const nowSec = Math.floor(Date.now() / 1000);
  const { findings, capped } = await crawl(projects.length ? projects : PROJECTS_DEFAULT, nowSec);

  // 上限到達は沈黙でドロップせず必ず報告(no silent caps)
  capped.forEach((c) =>
    process.stderr.write(`[scb-lint] capped: ${c.project} scanned ${c.scanned}/${c.total} pages (tail not scanned)\n`)
  );

  if (asJson) {
    process.stdout.write(JSON.stringify(findings, null, 2) + "\n");
    return;
  }
  if (findings.length === 0) {
    process.stdout.write("scb-lint: 機械的 findings なし\n");
    return;
  }
  const byType = findings.reduce((acc, f) => ({ ...acc, [f.type]: (acc[f.type] || 0) + 1 }), {});
  const fileable = findings.filter((f) => f.severity === "file");
  const digestOnly = findings.filter((f) => f.severity === "digest");
  process.stdout.write(`scb-lint: ${findings.length} findings  ${JSON.stringify(byType)}\n`);
  process.stdout.write(`  → WIP filing 対象(高精度): ${fileable.length} / digest のみ(孤立など): ${digestOnly.length}\n\n`);

  process.stdout.write(`== WIP filing 対象 (${fileable.length}) ==\n`);
  fileable.forEach((f) => {
    process.stdout.write(`● [${f.project}] (${f.type}) ${f.subject}\n`);
    process.stdout.write(`    Q: ${f.question}\n    ${f.url}\n\n`);
  });

  // digest-only は全部出すとノイジーなので、コンテンツ量上位だけ表示(残数は明示=no silent cap)
  const topDigest = [...digestOnly].sort((a, b) => (b.signal.charsCount || 0) - (a.signal.charsCount || 0)).slice(0, 15);
  process.stdout.write(`== digest のみ / 孤立ページ上位15 (全 ${digestOnly.length} 件・WIP化しない) ==\n`);
  topDigest.forEach((f) =>
    process.stdout.write(`· [${f.project}] ${f.subject}  (chars=${f.signal.charsCount})\n`)
  );
};

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
