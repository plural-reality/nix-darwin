#!/usr/bin/env node
// gtd-serve — Canvas を配り、カードの移動を Scrapbox へ書き戻すローカルサーバ。
//
//   node bin/gtd-serve.mjs "ToDoカンバン" plural-reality 8732
//
// ここが唯一の書き込み境界。SID はこのプロセスの中だけにあり、HTML には出ない。
// 書き戻しは save-to-scrapbox の CAS 手順(digest 一致 → 1回だけ送信 → 再取得検証)に従う。
// Canvas 自身は状態を持たず、書き込み後は必ず正本を読み直して描き直す。
import { createServer } from "node:http";
import { execFile } from "node:child_process";
import { writeFileSync, mkdtempSync, readFileSync, existsSync, mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { render, parse } from "./gtd-canvas.mjs";

const BIN = dirname(fileURLToPath(import.meta.url));
const [PAGE = "ToDoカンバン", PROJECT = "plural-reality", PORT = "8732"] = process.argv.slice(2);
const TMP = mkdtempSync(join(tmpdir(), "gtd-"));

// 読み取り(GET)は素通しでよいが、書き込み(POST)は必ずトークンを要る形にする。
// 盤の HTML にだけ埋め込むので、同一オリジンの script しか取り出せない
// = 他所のページから 127.0.0.1 を叩いて Scrapbox を書き換える経路を塞ぐ。
const TOKEN = ((dir, file) => {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  return existsSync(file)
    ? readFileSync(file, "utf8").trim()
    : ((tok) => (writeFileSync(file, tok, { mode: 0o600 }), tok))(randomBytes(24).toString("hex"));
})(join(process.env.HOME ?? "", ".local/share/gtd-canvas"),
   join(process.env.HOME ?? "", ".local/share/gtd-canvas/token"));

const run = (cmd, args, stdinFile, cb) =>
  execFile(
    "/bin/sh",
    ["-c", `${cmd} ${args.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ")}` +
      (stdinFile ? ` < '${stdinFile}'` : "")],
    { maxBuffer: 64 * 1024 * 1024 },
    (err, out, errOut) => cb(err ? new Error(errOut || String(err)) : null, out),
  );

// 正本の現在値と、契約どおりに計算した digest を一度に取る。
const snapshot = (cb) =>
  run("cosense-fetch", ["-r", PAGE, "-p", PROJECT], null, (e, raw) =>
    e
      ? cb(e)
      : ((file) => (
          writeFileSync(file, raw),
          run("/bin/sh", ["-c", `jq -cj '[.lines[].text]' '${file}' | shasum -a 256 | cut -d ' ' -f1`], null,
            (e2, digest) =>
              e2 ? cb(e2) : cb(null, { lines: JSON.parse(raw).lines.map((l) => l.text), digest: digest.trim() }),
          )
        ))(join(TMP, "raw.json")),
  );

// 階層は字下げ。見出しは星2つ以上(`[* x]` はただの装飾)。
const HEADING = /^([ \t]*)\[\*{2,}\s+.+\]$/;
const NOTE = /^[ \t]*[^[\s]/;
const STATUS = /^(\p{Extended_Pictographic}[️]*)/u;

// 行を1本抜いて、狙った升目の見出し(と説明行)の直後へ、その升目より1段深い字下げで差し込む。
const insertAt = (lines, laneIdx) =>
  lines.reduce(
    (found, l, i) =>
      found.at >= 0
        ? found
        : HEADING.test(l)
          ? found.n === laneIdx
            ? { n: found.n, at: i, pad: `${l.match(HEADING)[1]} ` }
            : { n: found.n + 1, at: -1, pad: " " }
          : found,
    { n: 0, at: -1, pad: " " },
  );

const moved = (lines, raw, laneIdx) =>
  ((without) =>
    ((spot) =>
      ((at) => [...without.slice(0, at), `${spot.pad}[${raw}]`, ...without.slice(at)])(
        spot.at < 0
          ? without.length
          : NOTE.test(without[spot.at + 1] ?? "")
            ? spot.at + 2
            : spot.at + 1,
      ))(insertAt(without, laneIdx)))(lines.filter((l) => l.trim() !== `[${raw}]`));

// done は盤から外す。完了の記録は正本のタスクページ側に ☑️ として残る。
const finished = (lines, raw) => lines.filter((l) => l.trim() !== `[${raw}]`);

// 完了タイトル = 先頭の状態絵文字を ☑️ に差し替える(無ければ付ける)。
const doneTitle = (raw) => `☑️${raw.replace(STATUS, "")}`;

// ページ本体を改名する。ページIDと履歴を保ち、被リンクも一括更新される専用 primitive を使う。
// 新タイトルで書くと別ページができて旧ページが幽霊タスクとして残るので、write ではなく rename。
const renameDone = (raw, cb) =>
  run("scrapbox-rename", [PROJECT, raw, doneTitle(raw)], null, (e) => cb(e));

const commit = (nextLines, digest, cb) => {
  const body = join(TMP, "body.txt");
  writeFileSync(body, nextLines.slice(1).join("\n"));
  run("scrapbox-write",
    ["--title", PAGE, "--project", PROJECT, "--mode", "replace", "--verbatim",
     "--expect-sha256", digest, "--dry-run"], body,
    (e) => (e ? cb(e) : run("scrapbox-write",
      ["--title", PAGE, "--project", PROJECT, "--mode", "replace", "--verbatim",
       "--expect-sha256", digest], body,
      (e2) => cb(e2 || null))));
};

const board = (cb) =>
  run(join(BIN, "gtd-fetch.sh"), [PAGE, PROJECT], null, (e, out) =>
    e ? cb(e) : cb(null, JSON.parse(out)),
  );

const send = (res, code, type, payload) => {
  res.writeHead(code, { "content-type": type, "cache-control": "no-store" });
  res.end(payload);
};

const onMove = (res, req) =>
  ((chunks) => {
    req.on("data", (c) => chunks.push(c));
    req.on("end", () =>
      ((wish) =>
        snapshot((e, snap) =>
          e
            ? send(res, 500, "application/json", JSON.stringify({ error: String(e.message).slice(0, 300) }))
            : wish.done
              ? // 先に改名(被リンク=看板の行も ☑️ に書き換わる)、そのあと看板から外す。
                renameDone(wish.raw, (rErr) =>
                  snapshot((e3, fresh) =>
                    e3
                      ? send(res, 500, "application/json", JSON.stringify({ error: String(e3.message).slice(0, 300) }))
                      : commit(
                          finished(finished(fresh.lines, wish.raw), doneTitle(wish.raw)),
                          fresh.digest,
                          (e4) =>
                            send(res, e4 ? 409 : 200, "application/json",
                              JSON.stringify(
                                e4
                                  ? { error: String(e4.message).slice(0, 300) }
                                  : { ok: true, renamed: !rErr,
                                      warn: rErr ? "ページの改名に失敗(盤からは外しました)" : undefined },
                              )),
                        ),
                  ),
                )
              : commit(moved(snap.lines, wish.raw, wish.lane), snap.digest, (e2) =>
                  send(res, e2 ? 409 : 200, "application/json",
                    JSON.stringify(e2 ? { error: String(e2.message).slice(0, 300) } : { ok: true })),
                ),
        ))(JSON.parse(Buffer.concat(chunks).toString("utf8"))),
    );
  })([]);

createServer((req, res) =>
  req.method === "POST" && req.url === "/move"
    ? req.headers["x-gtd-token"] === TOKEN
      ? onMove(res, req)
      : send(res, 403, "application/json", JSON.stringify({ error: "token 不一致(盤を再読み込みしてください)" }))
    : board((e, data) =>
        e
          ? send(res, 500, "text/plain; charset=utf-8", String(e.message))
          : send(res, 200, "text/html; charset=utf-8",
              render(parse(data.lines, data.external ?? {}), PROJECT, data.pages ?? {}, undefined, TOKEN)),
      ),
).listen(Number(PORT), "127.0.0.1", () =>
  console.log(`gtd-serve http://127.0.0.1:${PORT}  page=${PAGE} project=${PROJECT}`),
);
