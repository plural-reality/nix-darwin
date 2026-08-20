#!/usr/bin/env node
// node bin/gtd-canvas.test.mjs — 落ちたら parse/render の契約が壊れている。
import assert from "node:assert/strict";
import { parse, render } from "./gtd-canvas.mjs";

const FIXTURE = [
  "ToDoカンバン",
  "[tkgshn.icon]",
  "[プロジェクト看板]",
  "",
  "[** @5分・スマホ]",
  "",
  "[---.icon]",
  "",
  "[** Waiting for Someone]",
  " [⌛️GMOあおぞらネット銀行に登録している法人住所を更新する（審査待ち）]",
  " [⬜MozFestの参加チケットを取得する]",
  "",
  "[---.icon]",
  "",
  "[** Dependency]",
  " [🚨第1期法人税・地方税申告・納付（決算根拠の確認待ち）]",
  " [⌛️️音威子府PJでの経費精算のため、GMOに新しい口座を追加する]",
  "",
  "[** Agent Queue]",
  " [claude code WIP.icon]",
  " [* todo]",
];

const board = parse(FIXTURE);

// レーンは見出し行から導出され、順序は入力どおり。
assert.deepEqual(
  board.lanes.map((l) => l.name),
  ["@5分・スマホ", "Waiting for Someone", "Dependency", "Agent Queue"],
);
// 見出しが全部同じ段数なら木は平坦。子は生えない。
assert.deepEqual(board.lanes.map((l) => l.children.length), [0, 0, 0, 0]);
assert.equal(board.title, "ToDoカンバン");

// 見出しより上のページリンク([プロジェクト看板])はカードにしない。
assert.equal(board.lanes[0].cards.length, 0);

// 状態接頭辞を剥がし、正本リンク用の raw は原文のまま保つ。
assert.deepEqual(
  board.lanes[1].cards.map((c) => [c.status, c.label]),
  [
    ["waiting", "GMOあおぞらネット銀行に登録している法人住所を更新する（審査待ち）"],
    ["open", "MozFestの参加チケットを取得する"],
  ],
);
assert.equal(board.lanes[1].cards[0].raw, FIXTURE[9].trim().slice(1, -1));

// 異体字セレクタが重なった ⌛️️ も waiting に落ちる。
assert.deepEqual(
  board.lanes[2].cards.map((c) => c.status),
  ["alert", "waiting"],
);

// .icon 行と、その下のネストは一切カードにならない(Agent Queue は空)。
assert.equal(board.lanes[3].cards.length, 0);

// 同じ入力は同じ出力(傾きに乱数を使っていない)。
assert.equal(render(board, "plural-reality"), render(parse(FIXTURE), "plural-reality"));

// 正本リンクは原文タイトルで組む。
assert.ok(
  render(board, "plural-reality").includes(
    `https://scrapbox.io/plural-reality/${encodeURIComponent(board.lanes[2].cards[1].raw)}`,
  ),
);

// --- 見出しの段数が違えば、その通りに入れ子になる(レンダラは親を捏造しない) ---
// 入れ子は字下げで表す。星の数は見た目でしかない。
const NESTED = [
  "板",
  "[** Todo]",
  " いま自分で動かせるもの",
  " [** @5分・スマホ]",
  "  [⬜すぐ終わる]",
  " [** @PC]",
  "[** Waiting for]",
  " [** Someone]",
  "  [⌛️返事待ち]",
];
const tree = parse(NESTED);
assert.deepEqual(
  tree.lanes.map((l) => [l.name, l.children.map((c) => c.name)]),
  [
    ["Todo", ["@5分・スマホ", "@PC"]],
    ["Waiting for", ["Someone"]],
  ],
);
// 見出し脇の一言は正本(見出し直下の素のテキスト行)から来る。レンダラは語彙を持たない。
assert.equal(tree.lanes[0].note, "いま自分で動かせるもの");
assert.ok(render(tree, "plural-reality").includes("<h2>Todo<small>いま自分で動かせるもの</small></h2>"));
// 説明行はカードにならない。
assert.equal(tree.lanes[0].cards.length, 0);
// カードは原文そのまま = 先頭の絵文字がステータス。別ラベルは出さない。
assert.ok(render(tree, "plural-reality").includes('>⌛️返事待ち<span class="tip">'));
// リンク先本文を渡すと hover 用の吹き出しに入り、無ければ空である旨を出す。
assert.ok(
  render(tree, "plural-reality", { "⌛️返事待ち": "見出し\n本文の1行目" }).includes(
    '<span class="tip">見出し\n本文の1行目</span>',
  ),
);
assert.ok(render(tree, "plural-reality").includes('<span class="tip">（このページはまだ空）</span>'));
// 子を持つ節は容れ物として描かれ、葉だけがカードを持つ。
assert.ok(render(tree, "plural-reality").includes('class="lane group"'));

console.log("ok");
