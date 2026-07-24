// scrapbox-title-normalize — ステータス絵文字の VS16 (U+FE0F) 揺れを正規形へ畳む純関数。
//
// Scrapbox のリンク解決はバイト完全一致なので、同じ「☑」でも VS16 の個数(0〜2)が
// 違うだけで別ページになる。実測(2026-07-24 plural-reality 調査)では VS16 揺れだけで
// 延べ40ページ超のリンク切れが出た(例: ☑+VS16二重のタイトルが20ページから参照)。
// 書込み系ツール(scrapbox-write / scrapbox-rename)の入口で必ずこれを通す。
//
// 正規形:
//   ☑️ ⏹️ ⚠️ = VS16 ちょうど1個 (text-default 文字。絵文字表示に VS16 が必要)
//   ⬜ ⏳ ⌛ ✅ ❌ 🚨 = VS16 なし (emoji-default 文字。VS16 は冗長)
// 加えて、タイトル先頭に取り残された裸の VS16 (絵文字を剥がした際の残骸)を除去する。
//
// VS16 は不可視文字なので、このファイルでは必ず \uFE0F エスケープで書く(生で埋めない)。
const VS16 = "\uFE0F";
export const NEEDS_VS16 = "☑⏹⚠"; // ☑ ⏹ ⚠
export const NO_VS16 = "⬜⏳⌛✅❌\u{1F6A8}"; // ⬜ ⏳ ⌛ ✅ ❌ 🚨

const STATUS_RE = new RegExp(`([${NEEDS_VS16}${NO_VS16}])${VS16}*`, "gu");

export const normalizeStatusEmoji = (title) =>
  title
    .replace(new RegExp(`^${VS16}+`, "u"), "")
    .replace(STATUS_RE, (_m, c) => (NEEDS_VS16.includes(c) ? c + VS16 : c));
