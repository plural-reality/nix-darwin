---
name: scrapbox-llm-marking
description: Scrapboxで「人間が書いた文」と「LLMが書いた文」を視覚的に書き分け（[( …] 薄表示）、人間が承認（編集 or ワンクリック）したら濃く戻す/逆に灰色化する/打ち消し線で却下（素テキスト化）する仕組みを導入・再現する。AIスロップ防止。書き方の規約自体は save-to-scrapbox スキルが canonical。トリガー：「Scrapboxにこの書き分けの仕組みを入れて」「auto-humanize 導入」「承認ボタン」「打ち消しで却下」「AIスロップ防止」「別プロジェクト/新チームに展開」「deco 薄表示セットアップ」「人間とAIの書き分けを再現」
---

# Scrapbox 人間/LLM 書き分けシステムの導入・再現

人間が書いた文（濃い色）と LLM が書いた文（薄い灰色 `[( …]`）を視覚的に区別し、人間が「承認」した瞬間に濃い色へ昇格させる仕組み。承認は **①テキスト選択 → ポップアップの「承認」ボタン**（スマホ本命・複数行可）と **②灰色行を編集してカーソル/フォーカスを離す**（自動）の2通り。逆操作（白い本文を選択 → 「灰色に」）も可。さらに **③却下** — 灰色行に打ち消し線を引く（`[- [( X]]` の二重マークになる）と、灰色だけでなく内側のリンク・装飾も外して**素テキストの打ち消し `[- X]`** に正規化する（inert 化。承認＝リンク保持とは逆に、却下＝リンクも解除）。

**書き方そのものの規約**（`[( …]` の付け方・provenance・タスクの page object 化・TODO絵文字・agentアイコンなど）は **`save-to-scrapbox` スキルが canonical**。ここで再定義しない。このスキルは「その規約が *機能するための仕組み*」を導入・運用する側。

## なぜ
- 役割を「人間=骨子・判断 / LLM=調査・補足・整形」に分け、見た目でも分けると、誰が書いた・承認したかが一目で分かり AIスロップ（流暢だが無責任な量産文）が溜まらない
- Granola の「人間=黒字メモ / AI=灰字で下に補完」と同じ発想
- 解説記事（実例）: Scrapbox `tkgshn-private` の「ScrapboxをClaude Code / Codexで育てる：人間とAIの書き分けTips」

## アーキテクチャ（単一ソース）

コードの canonical は **public な `tkgshn-extension`** に**1コピーだけ**置く:
- `tkgshn-extension/llm-auto-humanize` — UserScript本体（承認UI + 自動humanize）
- `tkgshn-extension/cosense-ws-bundle` — `@cosense/std` の `patch` を self-host した bundle（~150KB、CSP回避）

各 project（`tkgshn-private` / `plural-reality` / …）は **自分の profile ページから import する1行だけ**を持つ:
```
import '/api/code/tkgshn-extension/llm-auto-humanize/script.js';
```
`tkgshn-extension` は `publicVisible=true` なので、どの project からも CSP を通って読める（public project 間の `/api/code` import は実証済み: `tkgshn-extension/script_all` が既に `scrasobox` / `villagepump` / `youkan-extension` を import している）。

→ **新 project / 新メンバーの追加は「profile に1行」だけ**。bundle や script のコピーは不要。コードを直すと全 project に即反映（source of truth が1つ）。

## 仕組みは3要素
1. **薄表示 deco CSS** — `[( …]` を opacity 0.5 で薄く表示。各 project の `settings` の UserCSS に入れると全員に効く
2. **self-host bundle**（canonical: `tkgshn-extension/cosense-ws-bundle`）— `@cosense/std` の `patch` を CSP回避のため Scrapbox 内に self-host
3. **UserScript**（canonical: `tkgshn-extension/llm-auto-humanize`）— 承認UI（PopupMenu）+ 自動humanize。per-user（profileページの code:script.js から import）

## 機能
- **承認（灰色→白）**: 灰色行(`[( …]`)を選択 → PopupMenu「承認」。複数行可。`[( X]`→`X`、`[( [X]]`→`[X]`、`[( X] \`#hash\``→`X \`#hash\``、`[(** X]`→`[** X]`（**装飾結合**: 太字等は残して `(` だけ外す）。**承認しても icon（署名）は付けない**＝承認後は人間の素の本文になる（旧 `[tkgshn.icon]` 署名や agent アイコンは除去）。
- **灰色に（白→灰色）**: 白い本文を選択 → PopupMenu「灰色に」。`X`→`[( X]`、`[** X]`→`[(** X]`（既存装飾を保ったまま `(` を足す）。冪等（既に灰色/空行は触らない）・往復可（`humanize(grayify(x))===x`）。
- **却下（打ち消し→素テキストの打ち消し）**: 人間が灰色LLM行に打ち消し線を引くと素朴には二重マーク `[- [( X]]` になる。これを「灰色除去後に `-` が残る行＝却下」とみなし、内側のリンク・装飾も `plain` で全解除して **`[- X]`**（素テキストの打ち消し）に正規化する。`[- [( Omi]]`→`[- Omi]`、`[- [( [Omi]]]`→`[- Omi]`（リンクも解除）、`[- [( …凍結(pendant.py…)]]`→`[- …凍結(pendant.py…)]`（丸括弧・日本語は不可侵）、`[- [( X]] \`#hash\``→`[- X] \`#hash\``（provenance 保全）。**元が灰色だった行（`[(` を含む）だけが却下対象**＝人間が自前で打ち消した非灰色リンクには触らない（`isDraft` ガード）。承認と同じ `humanizeLine` の分岐で表現し、自動（編集→離脱）と PopupMenu「承認」の両経路で発火。冪等（`[- X]` は再変換しない）。
- **自動承認/却下**: 灰色行を編集 or 打ち消してカーソル/フォーカスを離すと自動で白 or `[- …]` に。
- スマホ（モバイルブラウザ）対応。**Scrapbox/Cosense 公式アプリは UserScript が動かない**ので、モバイルでもブラウザで開く前提。

## 導入手順

### A. 既存の canonical を使う（推奨・既定）
新 project / 新メンバーは、自分の profile ページ `<project>/<自分の名前>` の code:script.js に1行足すだけ:
```
import '/api/code/tkgshn-extension/llm-auto-humanize/script.js';
```
その project にまだ薄表示 CSS が無ければ `settings` に追加（下記 B）。ブラウザをハードリロードし、コンソールに `[llm-auto-humanize] active (select-to-approve + auto)` が出れば成功。

### B. deco CSS（各 project の settings、初回のみ）
`<project>/settings` に:
```css
.deco-\( {
  opacity: 0.5;
}
```

### C. ゼロから別チーム/別組織に展開する（canonical が使えない環境）
`tkgshn-extension` にアクセスできない別組織では、自前で canonical を1つ立てる:
1. 本体を取得: `curl -s https://scrapbox.io/api/code/tkgshn-extension/llm-auto-humanize/script.js`
2. bundle を取得: `curl -s https://scrapbox.io/api/code/tkgshn-extension/cosense-ws-bundle/script.js`（または下記 esbuild で再生成）
3. 自組織の **public なハブ project** にこの2ページを置く（本体先頭の import 先 bundle パスを自組織のものに書き換える）
4. 各メンバーの profile からその本体を import

bundle 再生成（`@cosense/std` が無い/更新したい時。`@cosense/std` が入った node_modules のある場所で）:
```bash
# @cosense/std の browser websocket patch entry = esm/websocket/mod.js
npx --yes esbuild "<node_modules>/@cosense/std/esm/websocket/mod.js" \
  --bundle --format=esm --platform=browser --target=es2020 --outfile=/tmp/cosense-ws.mjs
# → 外部 import 0 の自己完結 ESM（patch を export）
```

### D. Scrapbox への code:ブロック書き込み（重要）
`code:script.js` ブロックへの書き込みは **`scrapbox-write` を使わない**（下記「空行バグ」）。`@cosense/std` の `patch` を直接使い、**code: ブロック内は空行を含め全行に先頭スペース1つ**を付ける（title + 各行 verbatim で全置換）。

## 実装の落とし穴（再現時に必ず踏む）
- **CSP**: 外部 script import（esm.sh 等）は弾かれる → ライブラリは self-host し、`'self'`(=scrapbox.io の `/api/code`) から import
- **code: ブロックの空行**: Scrapbox は**インデントでコードブロックの範囲を判定**する。空行（インデント0）でブロックが途切れ、以降の行が脱落する（import 行だけ残って本体が消える等）。**空行も先頭スペース1必須**。`scrapbox-write` は空行を `''` に潰すので code: ブロックを壊す → code 用途には使わない
- **ハッシュ接尾辞で全機能が不発**: 行末は provenance hash が付き `[( 本文] \`#sessionhash\`` の形になる。旧コードの `endsWith(']')` 判定はこれで **false** になり、承認ボタンも自動humanizeも**一切反応しなくなる**。`matchClose`（先頭 `[` に対応する `]` を括弧の深さで特定）で `[( ` に対応する `]` だけを外し、後続のハッシュは残す
- **#text-input は遅延生成 + SPA**: load時 `getElementById` では掴めない → `document` に capture デリゲート
- **id のズレ**: DOM `.cursor-line` の id は `L` プレフィックス付き、`scrapbox.Page.lines[].id` は無し → 照合時に `L` を除去
- **カーソル監視だけでは不発**: 編集後カーソルが同じ行に留まる / スマホは行移動せずキーボードを閉じる → 「前の行と違ったら」では発火しない。**`touched` Set（人間が触った行id）+ `focusout` + `beforeinput`/`compositionend`（モバイルIME対策）** で補完
- **人間/AIの区別**: AI は websocket(`patch`)で直接書く=`input`系イベントが飛ばない / 人間はエディタ DOM に飛ぶ。「input が起きた行 = 人間が触った行」
- **装飾結合 `[(** …]` で承認が不発**: 灰色は装飾文字 `(` で表現するので、太字等と結合すると `[(** 本文]`（`(`＋スペースではない）になる。`[( ` 前提（先頭3文字 `'[( '`）で剥がす旧 `unwrap` はこれを掴めず、承認ボタンも自動humanizeも無反応になる。**先頭の装飾トークン `[<装飾文字> <内容>]` を解析（`leadingDeco`）して装飾文字列から `(` だけ抜く**（`[(** X]`→`[** X]`、`(` 単独なら丸ごと外して `X`）。装飾文字は `( * / - _` に限定し、リンク `[Page Name]`（先頭語が装飾文字でない）を装飾と誤認しない
- **打ち消し線で包まれた灰色が不発（二重マーク）**: 人間が灰色行を打ち消すと `[- [( X]]` になる。`leadingDeco` を**1段しか見ない**旧 `ungray` は外側の `-`（`(` を含まない＝灰色でない）を見て素通りし、内側 `[(` が溶けず二重マークが残る。**`ungray` をネスト装飾へ再帰**させ、どの深さの `[(` も溶かす（承認時はリンク・太字を保持）。
- **backtick コードで1行に `[( ]` が複数並ぶ → 承認が途中で止まる**: Scrapbox 装飾ブラケット内では `` `code` `` が等幅表示にならず壊れる。そこで書き方規約（`save-to-scrapbox` が canonical）は**コードを `[( ]` の外に出し、プレーン区間ごとに個別装飾**する（例 `[( a] \`c\` [( b]`、生成は `daily-page.py` の `mark_gray`）。結果として **1行に兄弟の `[( ]` が複数**並ぶ。先頭の `[(` とそのネストだけ溶かす `ungray` では2つ目以降が承認後も灰色で残る。**`ungray` は行頭から `[…]` を1つずつ `matchClose` で確定し、灰色装飾(`(` を含む)なら溶かし、リンク `[Page]`・非灰色装飾 `[* …]` は温存し、残り(`after`)も再帰**する（`humanize('[( a]\`c\`[( b]') === 'a\`c\`b'`）。`grayify` は単一ブラケットのままでも新 `ungray` が溶かすので round-trip `humanize(grayify(x))===x` は不変。
- **却下（打ち消し）は別経路で素テキスト化**: 「灰色除去後に `-` が残る行＝却下」とみなし、`plain`（角括弧マークアップを全外し。丸括弧・日本語は**不可侵**＝`'['` が無ければ素通り、入れ子・複数リンクも再帰平坦化）で内側のリンク・装飾も外して **`[- 素テキスト]`** に正規化する。承認（リンク保持）と却下（リンク解除）は同じ `humanizeLine` の三項分岐 `struck ? [- plain(d.content)] : ungray(core)` で表現。**却下は元が灰色だった行（`core.includes('[(')`）だけ**＝人間が自前で打ち消した非灰色リンクには触らない。
- **humanize の規則**: `[( X]`→`X` / `[( [X]]`→`[X]`（内側リンク保持）/ `[( X] [* #h]`→`X [* #h]`（後続保持）/ `[(** X]`→`[** X]`（装飾結合: `(` だけ外す）/ **`[- [( X]]`→`[- X]`・`[- [( [Link]]]`→`[- Link]`（却下＝リンクも解除して inert 化）** / agent アイコン・旧 `[tkgshn.icon]` 署名を除去。**承認しても署名は付けない**（人間が承認＝その行は人間の本文。バッジ不要）
- **grayify は逆関数・冪等**: 既に灰色（装飾文字に `(` を含む）/ 空行は触らない（二重囲み `[( [( …]]` 防止）。装飾付き行は `(` を装飾文字へ足す（`[** X]`→`[(** X]`）。`humanize(grayify(x))===x`

## PopupMenu API（scrapbox-jp/types `scrapbox.ts` 一次情報）
```ts
addButton: (button: {
  // 関数にすると選択が変わるたび title を再計算。undefined を返すとボタン非表示。
  title: string | ((text: string) => string | undefined);
  // 選択テキスト（複数行は "\n" 連結のScrapbox記法）を受け取り、返した文字列で選択範囲を置換。
  onClick: (text: string) => string | undefined;
}) => void
```
これにより「承認対象が選択に含まれる時だけ『承認』を出す」「onClick の返り値で一括変換」が自然に書ける。

## 既に導入済みの実体
- canonical: `tkgshn-extension/llm-auto-humanize` + `tkgshn-extension/cosense-ws-bundle`（public）
- `tkgshn-private` と `plural-reality`: 各 `settings` に deco CSS、各人の profile に import 1行
- 旧 `tkgshn-private/llm-auto-humanize` 等は**転送スタブ**（canonical へ誘導。backlink を壊さないため削除せずスタブ化）

## 関連スキル

このスキルは「仕組みの導入・運用」側。実際に書くときの規約や読み取りは別スキル。

| スキル | 責務 |
|---|---|
| `save-to-scrapbox` | **書き方の canonical な規約**（`[( …]` の付け方、provenance、page object 化、agent アイコン等） |
| `scrapbox-context` | 既存ページの読み取り（書く前の調査） |
| `natural-writing` | AI文体パターン（24項目）の回避ガイド。Scrapbox に LLM 行を書く時の文体は必ずこれを参照 |
| `scrapbox-write` (CLI) | 通常ページの書き込み（`@cosense/std` patch、replace/append/prepend/dry-run）。**code: ブロックには使わない** |
