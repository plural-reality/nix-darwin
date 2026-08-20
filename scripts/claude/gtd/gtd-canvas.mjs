#!/usr/bin/env node
// gtd-canvas — 看板の本文とカードのリンク先本文を1つにした JSON を stdin で受け、
// 付箋レイアウトの read-only HTML を stdout へ吐く純粋 filter。
//
//   gtd-fetch.sh "ToDoカンバン" plural-reality \
//     | gtd-canvas --project plural-reality > canvas.html
//
// stdin: {"lines": ["…"], "pages": {"<カードのタイトル>": "<本文>"}}
// pages は hover プレビュー用。IO は gtd-fetch.sh 側にあり、ここは全域関数のまま。
//
// 契約:
//   - lane 語彙は入力の見出し行から導出する。レーン名を一切ハードコードしない。
//   - 書き込み境界を持たない。f(text) -> html の全域関数で、同じ入力は同じ出力になる。
//   - project 名だけが外から注入される設定(リンク先 URL の組み立てに要る)。

// 階層は Scrapbox 本来の字下げで表す。星の数は見た目の強調でしかなく、意味を持たせない。
//   `[** 名前]`     = 升目の見出し(星2つ以上)。字下げが1段深いものはその中身。
//   `[* x]`         = ただの装飾。升目ではない。
//   `[ページ名]`    = カード。直前の見出しに属する。
//   素のテキスト    = その見出しが何かを言う一言。
const INDENT = /^([ \t]*)(.*)$/;
const LANE = /^\[\*{2,}\s+(.+)\]$/;
const ITEM = /^\[(.+)\]$/;
const NOT_A_PAGE = /^(?:[*/\-_!"#%&]+\s|https?:)|\.icon$/;
// 見出し直下の素のテキスト行(リンクではない行)は、そのレーンが何かを言う一言。
// 語彙をレンダラに持たせないための入口 — 説明文も正本が持つ。
const NOTE = /^[^[\s].*$/;

const stripVS = (s) => s.replace(/\uFE0F/g, "");

// scrapbox-status skill の状態語彙。異体字セレクタを剥がしてから前方一致で判定する。
const STATUSES = Object.freeze([
  ["☑", "done"],
  ["\u{1F6A8}", "alert"],
  ["⌛", "waiting"],
  ["⏳", "progress"],
  ["⏹", "hold"],
  ["⬜", "open"],
  // Scrapbox に正本を持たない外部の予定。盤の上では動かせない。
  ["📅", "event"],
  ["⏰", "reminder"],
  ["📍", "place"],
]);

const EXTERNAL = Object.freeze(["event", "reminder", "place"]);

const classify = (raw) => {
  const bare = stripVS(raw).trim();
  const hit = STATUSES.find(([glyph]) => bare.startsWith(glyph));
  return hit
    ? { status: hit[1], label: bare.slice(hit[0].length).trim() }
    : { status: "none", label: bare };
};

// 先頭が yyyy/m/d のカードは、その日付を並び順の鍵にする。
// 日付を持たないカードは鍵を持たず、正本に書かれた順のまま後ろに残る。
const DATE = /^(\d{4})\/(\d{1,2})\/(\d{1,2})\b/;
const dueOf = (label) =>
  ((m) => (m ? `${m[1]}-${m[2].padStart(2, "0")}-${m[3].padStart(2, "0")}` : null))(
    label.match(DATE),
  );

const toCard = (raw, detail) =>
  ((c) => ({ ...c, raw, detail, due: dueOf(c.label), external: EXTERNAL.includes(c.status) }))(
    classify(raw),
  );

const PREVIEW_CHARS = 700;

// 締切日を持つカードだけは、レーンを手で分けずに日付から時間の升目を導出する。
// 「今日」は入力なので --today で受け取る。既定はシステム日付だが、渡せば出力は再現する。
const dayAfter = (iso, n) =>
  new Date(Date.parse(`${iso}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);

// 今週の終わり = 直近の日曜日。土日は休みなので「今週やること」はその日曜までを指す。
const weekEnd = (iso) => dayAfter(iso, (7 - new Date(`${iso}T00:00:00Z`).getUTCDay()) % 7);

const bucketsFor = (today) =>
  Object.freeze([
    { name: "今日", has: (d) => d <= today },
    { name: "明日", has: (d) => d === dayAfter(today, 1) },
    { name: "今週", has: (d) => d <= weekEnd(today) },
    { name: "もっと先", has: () => true },
  ]);

// 締切のあるカードを持つ葉は、時間の升目へ割り直した子を生やす。日付のないカードは残す。
const bucketed = (lane, today) =>
  lane.derived || lane.children.length > 0 || !lane.cards.some((c) => c.due)
    ? lane
    : {
        ...lane,
        cards: lane.cards.filter((c) => !c.due),
        children: bucketsFor(today).reduce(
          (acc, b) => ({
            rest: acc.rest.filter((c) => !b.has(c.due)),
            out: [
              ...acc.out,
              {
                name: b.name,
                idx: lane.idx,
                derived: true,
                cards: acc.rest.filter((c) => b.has(c.due)),
                children: [],
              },
            ],
          }),
          { rest: lane.cards.filter((c) => c.due), out: [] },
        ).out,
      };

// 直近が上。日付なしは末尾へ、互いの順は崩さない(安定ソート)。
const byDue = (cards) => [
  ...cards.filter((c) => c.due !== null).sort((a, b) => (a.due < b.due ? -1 : a.due > b.due ? 1 : 0)),
  ...cards.filter((c) => c.due === null),
];

const appendCard = (lanes, raw) => [
  ...lanes.slice(0, -1),
  { ...lanes.at(-1), cards: [...lanes.at(-1).cards, toCard(raw)] },
];

const flatten = (lines) =>
  lines.reduce(
    (acc, line) =>
      ((indent, body) =>
        ((lane, item) =>
          lane
            ? {
                ...acc,
                lanes: [
                  ...acc.lanes,
                  // 字下げが浅いほど外側。build() は level が大きいほど外側なので符号を反転する。
                  { name: lane[1], level: -indent.length, idx: acc.lanes.length, cards: [] },
                ],
              }
            : item && acc.lanes.length > 0 && !NOT_A_PAGE.test(item[1])
              ? { ...acc, lanes: appendCard(acc.lanes, item[1]) }
              : NOTE.test(body) && acc.lanes.length > 0 && acc.lanes.at(-1).note === undefined
                ? {
                    ...acc,
                    lanes: [...acc.lanes.slice(0, -1), { ...acc.lanes.at(-1), note: body }],
                  }
                : acc)(body.match(LANE), body.match(ITEM)))(
        ...line.match(INDENT).slice(1),
      ),
    { title: (lines.find((l) => l.trim() !== "") ?? "board").trim(), lanes: [] },
  );

// 入れ子は字下げだけで決まる。浅い見出しが容れ物、その後に続く深い見出しが中身になる。
// 全部同じ深さなら木は自然に平坦になる — レンダラ側が親を捏造しないための唯一の入口。
const attach = (items, i, outer, [children, j]) =>
  ((rest) => [[{ ...items[i], children }, ...rest[0]], rest[1]])(build(items, j, outer));

const build = (items, i, outer) =>
  i >= items.length || items[i].level >= outer
    ? [[], i]
    : attach(items, i, outer, build(items, i + 1, items[i].level));

const withExternal = (lane, external) =>
  ((extra) => (extra.length === 0 ? lane : { ...lane, cards: [...lane.cards, ...extra] }))(
    (external[lane.name] ?? []).map((x) => toCard(x.raw, x.detail)),
  );

export const parse = (lines, external = {}) =>
  ((flat) => ({
    title: flat.title,
    lanes: build(flat.lanes.map((l) => withExternal(l, external)), 0, Infinity)[0],
  }))(flatten(lines));

const esc = (s) =>
  s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

const href = (project, raw) =>
  `https://scrapbox.io/${encodeURIComponent(project)}/${encodeURIComponent(raw)}`;

// カードは正本ページそのものへのリンク。別タブで開き、盤を開いたまま辿れるようにする。
// hover 中に出る吹き出しはカードの子要素なので、吹き出しへマウスを移しても開いたまま読める。
const cardHtml = (project, card, pages) =>
  card.external
    ? `<span class="card ext" data-status="${card.status}">${esc(card.raw)}` +
      `<span class="tip">${esc(card.detail ?? "")}</span></span>`
    : ((body) =>
    `<a class="card" data-status="${card.status}" draggable="true"` +
    ` data-raw="${esc(card.raw)}" target="_blank" rel="noopener"` +
    ` href="${href(project, card.raw)}">` +
    `${esc(card.raw)}` +
    `<span class="tip">${
      body ? esc(body.slice(0, PREVIEW_CHARS)) + (body.length > PREVIEW_CHARS ? "\n…" : "")
           : "（このページはまだ空）"
    }</span></a>`)((pages[card.raw] ?? "").trim());

// ホワイトボードは深さごとに並ぶ向きが交互になっている。
// 最上段(Todo │ Waiting for │ Scheduled)は横、その中(@PC / @家 / @外出)は縦、
// さらにその中(10分 │ 30分 │ 1時間~)はまた横。レーン名を見ずに深さだけで決まる。
const dirAt = (depth) => (depth % 2 === 0 ? "row" : "col");

// 葉 = カードを置く升目。子を持つ節 = 容れ物で、中に子の盤を敷く。
const laneHtml = (project, raw_, depth, pages, today) =>
  ((lane) =>
  `<section class="lane${lane.name.startsWith("@") ? " ctx" : ""}${
    lane.children.length > 0 ? " group" : ""
  }" data-d="${depth}">` +
  `<h2>${esc(lane.name)}${lane.note ? `<small>${esc(lane.note)}</small>` : ""}</h2>` +
  // 容れ物にも自前のカード置き場を持たせる。子の上にあるので、Inbox は「まず放り込む場所」に
  // なり、その下に分類済みの升目が並ぶ。日付から作った升目は正本の行を持たないので落とせない。
  `<div class="drop"${lane.derived ? "" : ` data-lane="${lane.idx}"`}>${
    lane.cards.length === 0
      ? lane.children.length === 0
        ? '<p class="empty">空</p>'
        : ""
      : byDue(lane.cards).map((c) => cardHtml(project, c, pages)).join("")
  }</div>` +
  (lane.children.length === 0
    ? ""
    : `<div class="board ${dirAt(depth + 1)}">${lane.children
        .map((c) => laneHtml(project, c, depth + 1, pages, today))
        .join("")}</div>`) +
  `</section>`)(bucketed(raw_, today));

const STYLE = `
:root{--bg:#101516;--line:#3c4a49;--paper:#f4c84a;--ink:#22241c;--muted:#b7c3bf;--accent:#6ee7b7}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(circle at 20% 0,#253535 0,#101516 38%);color:#f5f7f5;
 font-family:-apple-system,BlinkMacSystemFont,"Hiragino Sans",sans-serif,
 "Apple Color Emoji","Segoe UI Emoji"}
.shell{max-width:1900px;margin:auto;padding:26px;min-height:100vh;position:relative;
 display:flex;flex-direction:column}
header{display:flex;justify-content:space-between;gap:20px;align-items:start;
 border-bottom:1px solid var(--line);padding-bottom:20px}
.eyebrow{color:var(--accent);letter-spacing:.14em;font-size:12px;font-weight:700}
h1{margin:7px 0 0;font-size:29px}
/* header は常に見えていてほしいので貼り付ける。done はそこに常駐するドロップ先。 */
header{position:sticky;top:0;z-index:20;background:#111a19;margin:-26px -26px 0;padding:18px 26px}
.done{border:1px solid #587468;background:#152724;color:#baf8d8;border-radius:999px;
 padding:10px 16px;font:inherit;font-size:13px;white-space:nowrap;cursor:default}
.done.over{border-color:var(--accent);background:#1d3b31;color:#fff}
.card{cursor:grab}
.card:active{cursor:grabbing}
.drop.over{outline:2px dashed var(--accent);outline-offset:-2px;border-radius:4px}
#msg{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);z-index:30;
 background:#0d1413;border:1px solid var(--accent);color:#dfeae5;border-radius:6px;
 padding:9px 15px;font-size:13px;display:none}
/* 層は箱ではなく区切り線で表す。ホワイトボードと同じで、塗られた面は付箋だけ。 */
.board{display:flex}
.board.row{flex-direction:row;flex-wrap:wrap;align-items:stretch}
.board.col{flex-direction:column}
/* 横に並ぶ升目は等分。カード1枚ぶんを下限とし、入らなくなったら折り返す。 */
.board.row>.lane{flex:1 1 0;min-width:210px}
.board.row>.lane+.lane{border-left:1px solid var(--line)}
.board.col>.lane+.lane{border-top:1px solid var(--line)}
/* 縦に積む升目は高さを等分する。あふれたカードは升目の中だけでスクロールさせる。 */
.board.col>.lane{flex:1 1 0}
.lane,.lane>.board{min-height:0}
.lane{overflow:hidden}
.shell>.board{overflow-x:auto;border-top:1px solid var(--line);margin-top:20px;
 flex:1;min-height:0}
.lane{display:flex;flex-direction:column;padding:12px 15px 15px}
.lane>.board{flex:1;margin-top:2px;overflow:auto}
.lane>h2{margin:0 0 10px;display:flex;justify-content:space-between;align-items:baseline;gap:8px;
 font-weight:700}
.lane>h2>small{font-weight:400;color:var(--muted);font-size:11px;text-align:right;
 flex:1;min-width:0}
.lane[data-d="0"]>h2{font-size:19px;letter-spacing:.01em}
.lane[data-d="1"]>h2{font-size:14px;color:#dbe8e2}
.lane[data-d="2"]>h2{font-size:12px;color:var(--muted);font-weight:600}
.drop{display:grid;gap:8px;align-content:start;min-height:0;overflow-y:auto;
 scrollbar-width:thin;scrollbar-color:#3c4a49 transparent}
.empty{margin:0;color:#4a5854;font-size:11px;padding:6px 0}
.card{display:block;background:var(--paper);color:var(--ink);padding:10px 12px;border-radius:2px;
 box-shadow:0 1px 2px rgba(0,0,0,.35);text-decoration:none;cursor:pointer}
.card{position:relative}
.card:hover{box-shadow:0 0 0 2px var(--accent),0 1px 2px rgba(0,0,0,.35)}
/* 吹き出しは position:fixed なので、升目の overflow に切り取られない。
   カードの子なので、吹き出しの上へマウスを移しても hover が続きスクロールして読める。 */
.tip{display:none;position:fixed;left:var(--x);top:var(--y);width:360px;max-height:46vh;
 overflow-y:auto;z-index:9;background:#0d1413;color:#dfeae5;border:1px solid var(--accent);
 border-radius:6px;padding:12px 14px;font-size:12px;font-weight:400;line-height:1.6;
 white-space:pre-wrap;box-shadow:0 10px 30px rgba(0,0,0,.55);
 scrollbar-width:thin;scrollbar-color:#3c4a49 transparent}
.card:hover>.tip{display:block}
.card{font-weight:700;font-size:13px;line-height:1.5}
.card[data-status="waiting"],.card[data-status="hold"],.card[data-status="progress"]{background:#ffea93}
.card[data-status="alert"]{background:#fda4af}
.card[data-status="done"]{background:#cfd8cf;color:#5a635a}
/* 外部の予定は正本を持たない = 掴めない。付箋ではなく「貼り紙」として区別する。 */
.card.ext{background:transparent;color:#cfe0d8;border:1px solid #43565160;border-left:3px solid #6b8f83;
 box-shadow:none;cursor:default;font-weight:400}
.card.ext:hover{box-shadow:none;border-color:var(--accent)}
footer{color:var(--muted);font-size:12px;line-height:1.6;margin-top:24px;
 border-top:1px solid var(--line);padding-top:16px}
footer a{color:var(--accent)}
@media(max-width:640px){.shell{padding:16px}header{display:block}.lock{display:inline-block;margin-top:12px}}
`;

export const render = (
  { title, lanes },
  project,
  pages = {},
  today = new Date().toISOString().slice(0, 10),
  token = "",
) =>
  `<!doctype html>
<html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} — GTD Canvas</title><style>${STYLE}</style></head>
<body><main class="shell">
<header><div><div class="eyebrow">COSENSE → DERIVED VISUAL PROJECTION</div>
<h1>${esc(title)}</h1></div><button class="done" id="done" type="button">\u{1F5D1} done</button></header>
<div class="board ${dirAt(0)}">${lanes.map((l) => laneHtml(project, l, 0, pages, today)).join("")}</div>
<footer>正本は <a href="${href(project, title)}">${esc(project)}/${esc(title)}</a>。
このページはその純粋な射影で、状態を持たず書き込みもしない。
レーンは入力の見出し行から導出しており、この HTML 側に語彙は無い。</footer>
<div id="msg"></div></main>
<script>const TOKEN=${JSON.stringify(token)};${PAGE_JS}</script></body></html>
`;

const argOf = (argv, flag, fallback) =>
  ((i) => (i >= 0 && argv[i + 1] ? argv[i + 1] : fallback))(argv.indexOf(flag));

// 吹き出しの位置決めだけの script。状態は持たず、DOM も足さない。
// 吹き出しの位置決めと、カードの移動。移動の実体は必ずサーバ側(CAS付き)で行い、
// この script は「どのカードをどこへ落としたか」を送るだけで、状態は一切持たない。
const PAGE_JS = `
const msg=(s)=>{const m=document.getElementById("msg");m.textContent=s;m.style.display="block";
  clearTimeout(m._t);m._t=setTimeout(()=>m.style.display="none",2600)};
document.addEventListener("mouseover",(e)=>{
  const card=e.target.closest?.(".card"); if(!card) return;
  const r=card.getBoundingClientRect(), w=376;
  card.style.setProperty("--x", (r.right+w<innerWidth ? r.right+8 : Math.max(8,r.left-w)) + "px");
  card.style.setProperty("--y", Math.min(r.top, innerHeight-Math.min(innerHeight*.46,360)-16) + "px");
});
let held=null;
document.addEventListener("dragstart",(e)=>{const c=e.target.closest?.(".card");
  if(!c) return; held=c.dataset.raw; e.dataTransfer.effectAllowed="move";
  e.dataTransfer.setData("text/plain",held)});
const targets=()=>[...document.querySelectorAll(".drop"),document.getElementById("done")];
document.addEventListener("dragover",(e)=>{const z=e.target.closest?.(".drop,.done");
  if(!z||!held) return; e.preventDefault(); e.dataTransfer.dropEffect="move"; z.classList.add("over")});
document.addEventListener("dragleave",(e)=>e.target.closest?.(".drop,.done")?.classList.remove("over"));
document.addEventListener("drop",async(e)=>{const z=e.target.closest?.(".drop,.done");
  if(!z||!held) return; e.preventDefault(); targets().forEach(t=>t?.classList.remove("over"));
  const body=z.id==="done"?{raw:held,done:true}:{raw:held,lane:Number(z.dataset.lane)};
  held=null; msg(z.id==="done"?"☑️ 完了にしています…":"Scrapbox へ書き戻し中…");
  const r=await fetch("/move",{method:"POST",
    headers:{"content-type":"application/json","x-gtd-token":TOKEN},
    body:JSON.stringify(body)});
  const j=await r.json().catch(()=>({error:"応答を読めませんでした"}));
  if(j.ok){ if(j.warn){msg(j.warn); setTimeout(()=>location.reload(),1800)} else location.reload() }
  else {msg("失敗: "+(j.error||r.status))}});
document.addEventListener("click",(e)=>{if(e.target.closest(".tip")) e.preventDefault()});
`;

const main = () => {
  const project = argOf(process.argv, "--project", "plural-reality");
  const today = argOf(process.argv, "--today", new Date().toISOString().slice(0, 10));
  const chunks = [];
  process.stdin.on("data", (c) => chunks.push(c));
  process.stdin.on("end", () =>
    ((input) =>
      process.stdout.write(
        render(parse(input.lines, input.external ?? {}), project, input.pages ?? {}, today),
      ))(
      JSON.parse(Buffer.concat(chunks).toString("utf8")),
    ),
  );
};

// import 時は実行しない(テストから parse/render を直接使うため)。
process.argv[1]?.endsWith("gtd-canvas.mjs") ? main() : null;
