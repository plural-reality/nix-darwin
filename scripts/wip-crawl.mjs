#!/usr/bin/env node
// wip-crawl — Scrapbox 全体を「[claude code WIP.icon] 未処理キュー」として走査する純検知フィルタ。
//
// source of truth は Scrapbox 自身（アイコンが消える = 処理済 = キューから外れる）。状態を別管理しない。
// 入力: project 名（args、既定 3 project） / 出力: 処理対象ページ一覧（既定=表 / --json=JSON）
//
// in-scope の定義（2026-07-24 ユーザー決定「全部検知して」で拡張。旧: 行頭アイコンのみ）:
//   実アイコン [claude code WIP.icon] を含む行すべて（行頭・行中・行末を問わない）。
//   問い型/委任型/対象外の分類は検知器ではなく skill 側の LLM step(スコープ再判定)が担う。
//   除外(ページ単位・機械的ノイズのみ): 自動取込ログ(2行目が "from [claude codeセッション]") /
//         アイコン定義ページ(title === "claude code WIP") / 全角ブラケットの引用(［…］は別文字なので自然に不一致)。
//
// ponytail: 「アイコンについて説明する行」(引用・解説)も拾いうるが、skill 側の再判定で捨てる方が
//   検知器に自然言語判定を持ち込むより単純。取りこぼし(検知漏れ)ゼロを優先する。
//
// 依存: cosense-fetch(検索 -s / 生取得 -r)。処理(リサーチ→灰色書込→アイコン削除)は別レイヤ(wip-process)。

import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { realpathSync } from "node:fs";

export const ICON = "[claude code WIP.icon]"; // 半角ブラケットの実アイコンのみ
export const PROJECTS_DEFAULT = ["plural-reality", "tkgshn-private", "takalog"];

// 構造的除外: 行頭(字下げ除く)が `[(` = Cosense の灰色(AI 記入)記法。灰色行は AI が書いた散文で、
//   その中のアイコンは「キューを確認した/未処理は0件」等の *言及* であって、人間が置いた実行対象マーカーではない。
//   人間の WIP マーカーは常に素の行(`@[icon]` / `整備中[icon]` 等)に置かれ、`[( )]` で包まれることはない
//   (灰色=AI / 素=human の正本規約)。この構造だけで daily-report 等の自己言及誤検知を NL 判定なしに落とす。
const isGrayMention = (t) => /^[\s　]*\[\(/.test(t);

// 純粋判定: 全文 lines(=cosense-fetch -r の .lines[].text 配列) から in-scope な WIP 行を返す。
export const inScopeLines = (title, lines) => {
  if (title === "claude code WIP") return [];
  if ((lines[1] || "") === "from [claude codeセッション]") return [];
  return lines.filter((t) => t.includes(ICON) && !isGrayMention(t));
};

// 純粋: WIP 行(index 指定)の本文自身または直前数行から、人間の問い/指示文を1つ拾う。
//   行末アイコン形式(「〜であってる？[claude code WIP.icon]」)はアイコンを除いた自行本文が最良の候補。
//   index を受け取るのは、同一文字列の WIP 行が複数あるとき indexOf が先頭に誤対応するため。
export const nearbyQuestion = (lines, idx) => {
  if (idx < 0 || idx >= lines.length) return "";
  const self = (lines[idx] || "").split(ICON).join("").replace(/^[\s　]+/, "").trim();
  if (self) return self;
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
    // 検索上限に到達 = それより古い言及ページを見ていない。静かに欠落させず stderr に出す。
    if (candidates.length >= 200)
      process.stderr.write(`wip-crawl: ${p}: search capped at 200 pages — older mentions not scanned\n`);
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
        questions: lines
          .map((t, i) => (t.includes(ICON) ? nearbyQuestion(lines, i) : ""))
          .filter(Boolean),
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

// main() 起動ガード: macOS では argv[1](呼出パス)が symlink 未解決(/tmp→/private/tmp,
// nix の .local/bin/wip-crawl→/nix/store/…)なのに対し import.meta.url は realpath 解決済で、
// 素の === 比較は symlink 経由の起動(=nix packaging 後の全実行)で常に false になり main() が走らない。
// 両辺を realpath 解決してから比較する。
const isMain = () => {
  try { return !!process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url); }
  catch { return false; }
};
if (isMain()) main();
