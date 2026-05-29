---
name: scrapbox-llm-marking
description: Scrapboxで「人間が書いた文」と「LLMが書いた文」を視覚的に書き分け（[( …] 薄表示）、人間が編集したら自動で人間色に戻す仕組みをプロジェクトに導入・再現する。AIスロップ防止。書き方の規約自体は save-to-scrapbox スキルが canonical。トリガー：「Scrapboxにこの書き分けの仕組みを入れて」「auto-humanize 導入」「AIスロップ防止」「別プロジェクト/新チームに展開」「deco 薄表示セットアップ」「人間とAIの書き分けを再現」
---

# Scrapbox 人間/LLM 書き分けシステムの導入・再現

人間が書いた文（濃い色）と LLM が書いた文（薄い色 `[( …]`）を視覚的に区別し、人間がその行を編集した瞬間に濃い色へ自動昇格させる仕組みを、Scrapbox プロジェクトに敷く手順とコード。

**書き方そのものの規約**（`[( …]` の付け方・provenance・タスクの page object 化・TODO絵文字・agentアイコンなど）は **`save-to-scrapbox` スキルが canonical**。ここで再定義しない。このスキルは「その規約が *機能するための仕組み*」をプロジェクトに導入する側。

## なぜ
- 役割を「人間=骨子・判断 / LLM=調査・補足・整形」に分け、見た目でも分けると、誰が書いた・承認したかが一目で分かり AIスロップ（流暢だが無責任な量産文）が溜まらない
- Granola の「人間=黒字メモ / AI=灰字で下に補完」と同じ発想
- 解説記事（実例）: Scrapbox `tkgshn-private` の「ScrapboxをClaude Code / Codexで育てる：人間とAIの書き分けTips」

## 仕組みは3要素
1. **薄表示 deco CSS** — `[( …]` を opacity 0.5 で薄く表示。project の `settings` の UserCSS に入れると全員に効く
2. **self-host bundle** — humanize が使う `@cosense/std` の `patch` を、CSP回避のため Scrapbox 内に self-host
3. **自動humanize UserScript** — 人間が薄い行を編集してカーソルを離すと `[( ` 装飾と末尾アイコンを自動で剥がす。per-user（プロフィールページの code:script.js）

## 導入手順（プロジェクト `<project>` に入れる）

### 1. deco CSS を settings に追加（全員に薄表示が効く）
`<project>/settings` ページに次の code ブロックを置く:
```css
.deco-\( {
  opacity: 0.5;
}
```

### 2. cosense-ws-bundle を self-host（CSP回避の肝）
Scrapbox の CSP は esm.sh 等の外部 import を弾く（許可は `'self'`(=scrapbox.io の /api/code) / `cdnjs.cloudflare.com` / `'unsafe-eval'`）。なので `@cosense/std` の browser patch を1ファイルにバンドルして Scrapbox 内に置き、`/api/code/...`（self）から import する。

- バンドル生成（`@cosense/std` が入った node_modules があるディレクトリで）:
```bash
# @cosense/std の browser websocket patch entry = esm/websocket/mod.js
npx --yes esbuild "<node_modules>/@cosense/std/esm/websocket/mod.js" \
  --bundle --format=esm --platform=browser --target=es2020 --outfile=/tmp/cosense-ws.mjs
# → 外部import 0 の自己完結 ESM（約150KB・patch を export）
```
- `/tmp/cosense-ws.mjs` を `<project>/cosense-ws-bundle` の `code:script.js` ブロックに書き込む。
  - 書き込みは **`@cosense/std` の node `patch` + `SCRAPBOX_SID`**（各行の先頭にスペース1つ付けて code ブロック化）。`scrapbox-write` は使わない（各行に空白を足すのでコードが壊れる）。

### 3. 自動humanize UserScript を self-host
`<project>/llm-auto-humanize` の `code:script.js` に次を置く（`<project>` を置換）:
```js
import { patch } from '/api/code/<project>/cosense-ws-bundle/script.js';

// AIが書いた薄表示 [( … ] 行を、人間が編集したら自動で人間色(装飾なし)に戻す。
// 末尾の codex / claude code アイコンも剥がす。内側の [リンク]/タスクは保持。
const humanize = (text) => {
  const m = text.match(/^(\s*)(.*)$/);
  let body = m[2].replace(/\s*\[(?:codex|claude code)\.icon\]\s*$/, '');
  if (body.startsWith('[( ') && body.endsWith(']')) body = body.slice(3, -1);
  return m[1] + body;
};

// DOM の .cursor-line id は "L<lineId>"、scrapbox.Page.lines[].id は "<lineId>"
const domCursorId = () => document.querySelector('.cursor-line')?.id ?? null;
const toLineId = (domId) => (domId ? domId.replace(/^L/, '') : null);

let prev = domCursorId();
let touched = false;
// #text-input は遅延生成 + SPA。document に capture デリゲートして人間の編集を検知。
// AIは websocket 経由で書く=このイベントは飛ばない → 人間/AIを区別できる。
document.addEventListener('input', (e) => {
  if (e.target && e.target.id === 'text-input') touched = true;
}, true);

setInterval(() => {
  const cur = domCursorId();
  if (cur === prev) return;
  const leftId = toLineId(prev);
  const wasTouched = touched;
  prev = cur;
  touched = false;
  if (!leftId || !wasTouched) return;
  const line = (window.scrapbox?.Page?.lines ?? []).find((l) => l.id === leftId);
  if (!line || !line.text.includes('[(')) return;
  const next = humanize(line.text);
  if (next === line.text) return;
  patch(window.scrapbox.Project.name, window.scrapbox.Page.title, (ls) =>
    ls.map((l) => {
      const t = typeof l === 'string' ? l : l.text;
      const id = typeof l === 'string' ? null : l.id;
      return id === leftId ? next : t;
    })
  ).catch((e) => console.error('[llm-auto-humanize] patch error', e));
}, 250);

console.log('[llm-auto-humanize] active');
```

### 4. 各メンバーが自分のプロフィールページで有効化（per-user）
Scrapbox の UserScript はプロジェクト全体ではなく「自分のプロフィールページ（`<project>/自分の名前`）の code:script.js」に書くと*自分だけ*に効く。次の1行を足す:
```
import '/api/code/<project>/llm-auto-humanize/script.js';
```
→ ブラウザをハードリロード。コンソールに `[llm-auto-humanize] active` が出れば成功。`[( …]` 行を1文字編集してカーソルを離すと濃く戻る。

## 実装の落とし穴（再現時に必ず踏む）
- **CSP**: 外部 script import は弾かれる → ライブラリは self-host（手順2）
- **#text-input は遅延生成**: load時の `getElementById` では掴めない → `document` に capture デリゲート
- **id のズレ**: DOM `.cursor-line` の id は `L` プレフィックス付き、`scrapbox.Page.lines[].id` は無し → 照合時に `L` を除去
- **既存ページの書き換え**: `scrapbox-write`（各行に空白1足す）でなく `@cosense/std` の `patch` で現在行を変換（インデント保持）
- **humanize の規則**: `[( X]`→`X` / `[( [X]]`→`[X]`（リンク・タスクは保持）/ 末尾 `[agent.icon]` 除去

## 既に導入済みの実体（コピペ元）
- `tkgshn-private` と `plural-reality` の両方: `cosense-ws-bundle` / `llm-auto-humanize` ページ、`settings` の `.deco-(` CSS
- 各人の有効化は `<project>/自分の名前` の code:script.js に import 1行

## 関連
- 書き方規約（canonical）: `save-to-scrapbox` スキル
- 書き込みCLI: `scrapbox-write`（`@cosense/std` patch、replace/append/prepend/dry-run）
- 読み取り: `scrapbox-context` スキル
