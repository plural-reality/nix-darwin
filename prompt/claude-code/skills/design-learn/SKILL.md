---
name: design-learn
description: >
  視覚訂正 → デザイン skill トークンへの還流ループ(self-learn のデザイン版）。
  ユーザーが成果物(スライド/資料/Web)に付けた見た目の訂正を回収し、canonical テーマ・
  トークンの編集提案に distill し、工房の永続 decision 面で承認を取り、publish-skill → nix で
  恒久反映する。トリガー: 「デザイン訂正を学習」「見た目の直しを反映」「/design-learn」、
  および review-page に design/visual タグ付きコメントが溜まったとき。
---

# design-learn — 視覚訂正の学習ループ（P5 / §5 learn-from-corrections）

`self-learn` がテキスト事実を auto-memory に還流させるのと同型の、**デザイン版**。
「ユーザーが Docs/Slides/資料の *見た目* を直した」その訂正を、
`design-format-*` / `plural-reality-design-system` の **canonical トークンの編集**へ落とす。
これが無いと視覚訂正はエクスポート済み成果物に埋もれ、skill に一切戻らない(= このループが埋める空白)。

正本契約: `~/Developer/reviewable-html-workbench/UNIFIED-HARNESS.md` §5 / §8-Q4。owner = design スレッド。

## 5 ステップ

### 1. 捕捉（design/visual タグ・SPA改変不要）
訂正は **review-page のコメント**に、本文へ `#design` または `#visual`(大小無視)を含めて残す。
= 既存 comment channel にそのまま乗る(第一級のタグ欄を SPA に足さない=概念最小)。
将来 β(成果物 export の edit-diff)を第二の入力源に足せるが、まずは α(コメント)。

### 2. 回収（collector・機械的）
```bash
# ローカル: ingest-review 済みの comments.json / review 出力ディレクトリから
python3 scripts/collect_design_feedback.py <comments.json | <review-output-dir> [..]
# 永続(工房 DB)側は ingest-review で comments.json に落としてから同じく渡す
```
出力 = `{count, items:[{source, block_id, selected_text, comment, tags, target_hint{token_area,skill}, created_at}]}`。
`target_hint` は訂正文から **編集すべきトークン領域**(spacing/color/radius/typography/layout…)と
**標的 skill**(format 特定 or 傘)を推定する当たり。自己検証: `--selfcheck`。

### 3. distill（LLM・提案化）
回収 item ごとに、標的 skill の **現行トークンを読み**、訂正文を **具体的な before→after のトークン編集**に翻訳する。
- 例: 「カードの余白が広すぎ・詰めて」+ ir-slides → `--slide-pad: 48px → 40px`(または `.dark-card` padding)。
- 例: 「teal が強すぎ・控えめに」+ 傘 → `--brand` の使用量規則/彩度、または該当箇所の適用面積。
- 値は当てずっぽうにしない。**現行値を実測 → 訂正の方向に最小変更**。曖昧なら承認面で候補を複数出す。
- D2 の確定(傘と形式A–E は統合せず用途で分ける)を尊重。傘への訂正を形式に波及させない/その逆もしない。

### 4. 承認（工房の永続 decision 面を再利用＝再帰）
提案トークン編集を **raw-html の decision ページ**として publish し、ユーザーが各編集を承認/却下する。
```bash
# scratchpad の publish_raw.py 相当: POST /api/publish {kind:"raw-html", html}
# body は submitAnswers() 規約(persistent=親へ postMessage → /submit → submissions)
```
= このループの承認 UI は、P5 で開通した submit-bridge の上に載る(治具は捨て、回答は submissions に残る)。
単純な 1〜2 件なら AskUserQuestion でも可(ルーティングは §4 の下限)。

### 5. 反映（publish-skill → nix）
承認された編集だけを **canonical**(`~/Developer/plural-reality/nix-darwin/prompt/claude-code/skills/<skill>/SKILL.md`)の
トークンに適用し、`publish-skill`(→ nix / darwin-rebuild)で恒久化。skill 内容編集は即ライブ。
適用後は grep で before→after を裏取り(実測検証・自己申告にしない)。

## ガード（不変条件）
- **canonical にだけ書く**: ランタイム `~/.claude/skills`(nix store 由来・読取専用)でなく nix-darwin 側の source。
- 値は現行トークン実測に基づく最小変更。推測値を勝手に確定しない → 曖昧は承認面で候補提示。
- 傘 ⇄ 形式A–E を混ぜない(D2)。標的 skill は `target_hint.skill` を起点にユーザー承認で確定。
- 承認無しに publish しない(self-learn の text 自動追加と違い、デザイン値は視覚影響が大きい=常に人間承認)。
- 反映は必ず readback(grep で before→after 確認)。

## self-learn との関係
- テキスト事実 = `self-learn` → auto-memory。視覚パラメータ = `design-learn` → design skill トークン。
- 両者は別 store・別 channel。混ぜない(違うものに違う名前)。
