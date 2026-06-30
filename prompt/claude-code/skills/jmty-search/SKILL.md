---
name: jmty-search
description: ジモティー(jmty.jp)の出品を地域・価格・サイズ・年式で絞り、新規候補をランキング提示し、必要なら Scrapbox の ⏳個別ページに落とす。dedup は既存 Scrapbox の article-ID が source of truth。トリガー:「ジモティーで探して」「ジモティーの新着」「冷蔵庫/洗濯機 中古で探して」「jmty」「jmty-search」、新居の家電探索の続き。
---

# jmty-search — ジモティー出品フィルタ

`~/Developer/jmty-watch` の純粋フィルタ（一覧HTML→採点→dedup→任意でenrich/Scrapbox化）を会話から駆動する。
**件数のさばき方**＝一覧カードだけで圧縮→既知(Scrapbox)を除外→数件だけ記事補完。Scrapbox(`冷蔵庫`/`洗濯機` とその個別ページ)が「探索中/着手済み」の唯一の source of truth。

## ⚠️ 前提（毎回意識する）
- ジモティー規約 第2.1.3.6 は自動収集を禁止＝**本ツールは規約に抵触する**。ユーザー承知の上の個人利用。礼儀正しく（低速・最小取得・shortlistのみ記事fetch）。
- **本番 `--write`（Scrapboxへのページ生成・ハブ追記）はユーザー承認後のみ**。必ず先に `--write --dry` でプレビューを見せる。

## ツール
- 場所: `~/Developer/jmty-watch`（node が PATH にあれば直接、無ければ `nix develop`）
- カテゴリ: `reizoko`(冷蔵庫 g-1103) / `sentakuki`(洗濯機 g-1087)。他カテゴリは `lib/criteria.mjs` の `CRITERIA` に追加（gid・価格・サイズ・地域・reject/keep）。
- 条件(地域=不動前近隣・価格・サイズ・2022年以降…)は `lib/criteria.mjs`。**Scrapbox の `冷蔵庫`/`洗濯機` ページの制約と一致させる**（ズレたら criteria 側を直す＝SoTはScrapbox）。
- `SCRAPBOX_SID` 環境変数が `--write` に必須（セッションに設定済み）。

## 手順

### 1. 検索して候補を提示
```sh
cd ~/Developer/jmty-watch
node bin/jmty.mjs <reizoko|sentakuki> [--pages N] [--enrich]
```
- 出力の表（◎条件クリア / ?要確認）をユーザーに提示。**本命を1〜2件、理由つきで強調**（価格・地域の近さ・年式・サイズ適合・引取条件）。
- `--enrich`: 容量/寸法が空の候補だけ記事を1件ずつ取りに行く（低速）。サイズで絞りたい時に使う。
- `--pages N`: 1ページ(約50件)で足りなければ深掘り。
- 既知(Scrapboxに既にある)候補は自動で除外される（"既知 N件除外" と表示）。

### 2. Scrapbox に落とす（任意・承認制）
ユーザーが「これ登録して/Scrapboxに入れて」と言ったら:
```sh
node bin/jmty.mjs <cat> --write --dry      # ← まずプレビュー(書き込みなし)
```
- 生成される `⏳ <品>, ジモティー<区> ¥<price>` ページ群と、ハブ(`冷蔵庫`/`洗濯機`)へ追記される 🆕 行を提示し、**承認を取る**。
- OKなら本番:
```sh
node bin/jmty.mjs <cat> --write            # 個別ページ生成＋ハブに🆕追記
```
- 書込対象は hard-filter を通った全件（◎＋?）。多すぎる時は `--limit N`（既定12）。
- dedup により**再実行で既存ページを上書きしない**（既知IDは候補に出ない）。ユーザーが後で ⏹️/☑️ に変えたページは保護される。

### 3. 連絡まで進める場合
個別ページ生成後、実際に問い合わせるのはユーザー（jmtyログインが要る）。ステータス遷移(⏳→⏹️/☑️)は会話で依頼されたら該当ページを編集（リネーム＋ハブのバックリンク追従）。

## 補完・拡張
- パイプ用に `--json`（JSON Lines）。`node bin/jmty.mjs reizoko --json | jq ...` で二次加工。
- 規約準拠の常時監視が欲しい場合は email-digest（Gmail の jmty 新着アラートを入力源にする）を併設候補として提案（要・冷蔵庫アラートの手動登録）。
- HTML構造が変わって0件/壊れたら `lib/parse.mjs` のセレクタ（`p-articles-list-item` 等）を修正。

## 関連
- 買い物カタログ: Scrapbox `⌛️新居で何を買うか` / `冷蔵庫` / `洗濯機`（tkgshn-private）
- 受取は `ちゃんじゅ東京滞在`(6/12-15)に二人で、を前提に日程交渉
