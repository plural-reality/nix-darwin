#!/usr/bin/env node
// wip-crawl — Scrapbox 全体を「[claude code WIP.icon] 未処理キュー」として走査する純検知フィルタ。
//
// source of truth は Scrapbox 自身（アイコンが消える = 処理済 = キューから外れる）。状態を別管理しない。
// 入力: project 名（args、既定 3 project） / 出力: 処理対象ページ一覧（既定=表 / --json=JSON）
//
// in-scope の定義（メモリ feedback_wip_icon_research_workflow 準拠）:
//   ある行の「先頭の非空白トークンが [claude code WIP.icon]」= 未解決の問いマーカー。
//   除外: 「整備中[claude code WIP.icon]」(進行中タスク) / 自動取込ログ(2行目が "from [claude codeセッション]") /
//         アイコン定義ページ(title === "claude code WIP") / 全角ブラケットの引用(［…］) / 行中・行末の埋め込み。
//
// ponytail: 判定は「行頭が実アイコン」に限定（実データで検証済み）。上限=行末に置かれたアイコン
//   （例「〜であってる？[claude code WIP.icon]」）は拾わない。必要になったら inScopeLines に
//   「？を含む行の行末アイコン」も in-scope として足す（誤検知に注意）。
//
// 依存: cosense-fetch(検索 -s / 生取得 -r)。処理(リサーチ→灰色書込→アイコン削除)は別レイヤ(wip-process)。

import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";

export const ICON = "[claude code WIP.icon]"; // 半角ブラケットの実アイコンのみ
export const PROJECTS_DEFAULT = ["plural-reality", "tkgshn-private", "takalog"];

// 純粋判定: 全文 lines(=cosense-fetch -r の .lines[].text 配列) から in-scope な WIP 行を返す。
export const inScopeLines = (title, lines) => {
  if (title === "claude code WIP") return [];
  if ((lines[1] || "") === "from [claude codeセッション]") return [];
  return lines.filter((t) => t.replace(/^[\s　]+/, "").startsWith(ICON));
};

// 純粋: WIP 行の直前数行から、人間の問い(？ or [tkgshn.icon] を含む行)を1つ拾う。
export const nearbyQuestion = (lines, wipLine) => {
  const idx = lines.indexOf(wipLine);
  if (idx < 0) return "";
  for (let j = idx - 1; j >= Math.max(0, idx - 4); j--) {
    const t = lines[j] || "";
    if (/[？?]/.test(t) || t.includes("[tkgshn.icon]")) return t.replace(/^[\s　]+/, "");
  }
  return "";
};

const run = (cmd, cmdArgs) =>
  new Promise((resolve) =>
    execFile(
      cmd,
      cmdArgs,
      { maxBuffer: 64 * 1024 * 1024, env: { ...process.env, LANG: "ja_JP.UTF-8", LC_ALL: "ja_JP.UTF-8" } },
      (err, stdout) => resolve(stdout || "")
    )
  );

const parseJson = (s) => { try { return JSON.parse(s); } catch { return null; } };

const crawl = async (targetProjects) => {
  const found = [];
  for (const p of targetProjects) {
    const sj = parseJson(await run("cosense-fetch", ["-s", "claude code WIP", "-p", p, "-l", "200"]));
    const candidates = sj && Array.isArray(sj.pages) ? sj.pages.map((x) => x.title) : [];
    for (const title of candidates) {
      const rj = parseJson(await run("cosense-fetch", ["-r", title, "-p", p]));
      const lines = rj && Array.isArray(rj.lines) ? rj.lines.map((l) => l.text ?? "") : [];
      const wip = inScopeLines(title, lines);
      if (wip.length === 0) continue;
      found.push({
        project: p,
        title,
        url: `https://scrapbox.io/${p}/${encodeURIComponent(title.replace(/ /g, "_"))}`,
        wipCount: wip.length,
        questions: wip.map((w) => nearbyQuestion(lines, w)).filter(Boolean),
      });
    }
  }
  return found;
};

const main = async () => {
  const args = process.argv.slice(2);
  const asJson = args.includes("--json");
  const projects = args.filter((a) => !a.startsWith("--"));
  const found = await crawl(projects.length ? projects : PROJECTS_DEFAULT);

  if (asJson) { process.stdout.write(JSON.stringify(found, null, 2) + "\n"); return; }
  if (found.length === 0) { process.stdout.write("WIP queue: empty（未処理の [claude code WIP.icon] なし）\n"); return; }
  process.stdout.write(`WIP queue: ${found.length} page(s)\n\n`);
  for (const f of found) {
    process.stdout.write(`● [${f.project}] ${f.title}  (WIP×${f.wipCount})\n`);
    for (const q of f.questions) process.stdout.write(`    Q: ${q}\n`);
    process.stdout.write(`    ${f.url}\n\n`);
  }
};

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
