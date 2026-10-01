---
name: plural-reality-design-system
description: >
  多元現実（Plural Reality）のブランド正本。対外の資料・スライド・Web・文書をつくるとき、
  用途に合う design-format-* への振り分け、ロゴの使い方、会社名・製品名・日付・出典などの表記規約、
  値の唯一の定義元 tokens.css の使い方を示す。表記と配色は scripts/brand-lint で検査できる。
  トリガー例: "資料を作って", "スライド作成", "デザインに合わせて", "ブランドガイド",
  "プレゼン", "表記ルール", "会社名の書き方", "design system", "corporate identity"
---

# Plural Reality Design System（傘）

この skill は「どの形式で作るか」「ロゴ」「表記」「値の参照先」だけを決める。
色・書体・ウェイト・角丸・余白・動きの値は **`tokens.css` にだけ**書く。この SKILL.md にも design-format-* にも値は書かない。

決定の出典: `_brand-unification-2026-10-01/DECISIONS.md`（A1 色、A2 書体、A3 ブランド構造、A4 会社名、A5 製品名、D1 表記、E3 正本）。

## 0. この skill の中身

| パス | 役割 | 正本か |
|---|---|---|
| `tokens.css` | 値の唯一の定義元（色・書体・ウェイト・角丸・余白・動き・register） | **正本** |
| `style-guide.md` | 表記規約（会社名・製品名・日付・数値と出典・図表・免責・©・用語集） | **正本** |
| `SKILL.md`（このファイル） | 用途の振り分け・原則・ロゴ規定 | **正本** |
| `assets/mark.svg`, `assets/mark-white.svg` | 承認済みロゴマーク（HP repo からの複製。下記 §4） | 正本の複製 |
| `scripts/brand-lint` | 表記・配色の検査（下記 §6） | — |
| `scripts/deck-to-pdf.py` | HTML デッキを1スライド1ページの PDF にする | — |
| `reference/design-dna-palantir.json` | Palantir の視覚言語の**観察記録**。参考資料であり正本ではない。値を成果物に写さない | 非正本 |

Drive「デザインシステム」フォルダは原典 PDF と過去の書き出しの置き場で、正本ではない（2026-10 時点で teal・Public Sans の旧版のまま）。

## 1. 用途の振り分け

| 用途 | skill | register（`tokens.css`） |
|---|---|---|
| Web・LP・プロダクト UI・画面投影 | `design-format-web` | `screen`（既定・ダーク） |
| IR・決算・ピッチ・事業報告スライド | `design-format-ir-slides` | `document`（白）。印刷・配布するなら `print` |
| ホワイトペーパー・技術文書・導入ガイド | `design-format-whitepaper` | `print` |
| 協業資料・ケーススタディ・導入事例 | `design-format-partnership` | `print` |
| サービス定義書・仕様書・RFP 回答・公的調達 | `design-format-service-def` | `print` |
| 上のどれにも当たらない汎用の対外物（名刺・メール署名・ポスター） | この skill の §2〜§5 だけで作る | 画面なら `screen`、紙なら `print` |

- 自治体・企業に渡す資料は印刷され白黒コピーされる前提で `print` を選ぶ。ダークは画面専用。
- プロダクト（倍速会議・倍速アンケート）は endorsed 構造（A3）。プロダクトのロゴとアクセント1色、LP の演出は製品側で決めてよい。フッターの会社マーク・会社表記・法務リンク・中立色・書体・lucide アイコンはこの skill に揃える。

## 2. tokens.css の使い方

- **自己完結 HTML**（資料・スライド・単発ページ）: `tokens.css` の中身を `<style>` にそのまま inline する。外部 CSS を参照すると共有時に崩れる。
- **register の指定**: `<html data-register="document">` のように付ける。要素単位でも付けられる（例: 白いスライドの中の1枚だけ `screen`）。`@media print` では自動的に `print` 相当になる。
- **書体の読込**（Web で配信する場合）:

  ```html
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Geist:wght@300;400;500;700&family=JetBrains+Mono:wght@400;500&family=Noto+Sans+JP:wght@300;400;500;700&display=swap" rel="stylesheet" />
  ```

  印刷用 PDF を `scripts/deck-to-pdf.py` で出すときは外部フォントの link が除去されるので、ローカルに Geist と Noto Sans JP が入っている環境で書き出す。
- **値を書かない**: 成果物の CSS には `var(--accent)`、`var(--fg-muted)`、`var(--radius)` のように変数で書く。hex・フォント名・px の角丸を直書きしない。足りない値が必要になったら `tokens.css` に足してから使う。
- **HP（`plural-reality/website`）**: `client/src/index.css` の `:root` / `.dark` の値を `tokens.css` から同期する（互換名 `--background` `--brand` などを定義済み）。HP 側の移行は別 PR（E1）。
- **docx / pptx**: 色は `tokens.css` の hex をそのまま使う。書体は欧文 Geist、和文（eastAsia 属性）Noto Sans JP。Office の環境に無い場合の代替は欧文 Arial・和文 BIZ UDPゴシック。

## 3. 原則

- **モノクロ基調＋単一のアクセント**。アクセントは emerald（`--accent` / `--accent-ui`）だけで、面積は画面の5%以下、1画面1〜2箇所。teal は廃止（A1）。
- **アクセントの上の文字は黒**（`--accent-fg`）。白文字は 2.22:1 で読めない。
- **アクセントで文字を塗らない**。本文・リンク・見出しは `--fg`。リンクは下線で示す（`text-decoration-color: currentColor`）。白黒コピーでも分かる符号化にする。
- **チャートは常にモノクロ**。過去は中空、当期は塗り、系列は線種・ハッチ・直接ラベルで区別する。色だけで意味を持たせない。
- **角丸は 0**。完全な円と pill（ドット・アバター・ステータス）だけ `--radius-pill`。写真・カード・パネル・ボタン・スライドに中間の角丸を付けない。
- **ウェイトは 300 / 400 / 500**。700 は KPI の数値だけ。見出しは 400 以下。
- **影とグラデーションは使わない**。例外は写真の上の文字を読ませる暗幕 `--scrim`・`--fg-on-photo`・`--text-shadow-on-photo` だけ。
- **文字の濃さは3段**（`--fg` / `--fg-muted` / `--fg-subtle`）。不透明度で文字を薄くしない（コントラストが測れなくなる）。
- **和文に斜体を掛けない**。強調はウェイトか下線。
- **ラベル**: 日本語で書く。英字ラベルは固有名詞・略語に限る。`text-transform: uppercase` は欧文にしか効かないので、和文ラベルは `--tracking-label-ja` を使う。
- **アイコン**は lucide（線画、stroke 1.5）。絵文字は使わない。
- **写真**: 実在のチーム・顧客・現場・プロダクト UI だけ。ストックフォトは使わない。
- **動き**は意味のあるものだけ（フェード・控えめな上方移動）。`--duration-*` と `--ease` を使う。

## 4. ロゴ

承認済みマークは HP repo `plural-reality/website` の `client/public/brand/mark.svg`（三つのパスでできた承認済みベクターマスター。website #47 で導入、同ディレクトリの README.md に規定）。この skill の `assets/` は複製で、HP 側を更新したら複製も更新する。

| ファイル | sha256（複製時点 2026-10-01） | 用途 |
|---|---|---|
| `assets/mark.svg` | `529a65a991fd14226ffa3fe532f6049fe03f6277989857275e958f4b4eb84459` | 白・明るい地（`document` / `print`） |
| `assets/mark-white.svg` | `ae8e1d77dd444801260040423ec41e528207308e28a57b824ccbaee68ae1ab07` | 黒・暗い地（`screen`） |

- **色**: 墨（`mark.svg` の色のまま）か白（`mark-white.svg`）の単色だけ。emerald・グラデーション・写真の上の直置きは不可（写真に載せるときは暗幕を敷いて白版）。
- **最小サイズ**: マークの高さ 16px（画面）／4mm（紙）。これより小さくするときは favicon（`client/public/favicon.svg`）を使う。
- **余白**: SVG の viewBox に含まれる余白（マーク高さの約7%）を最小とし、ほかの要素との間はマーク高さの 1/4 以上空ける。
- **変形しない**: パスの形・比率・隙間を変えない。回転・縦横比の変更・影・枠囲みをしない。
- **ワードマーク**: 輪郭化した承認済みワードマークは無い。社名を添えるときはマークの右に `--font-sans` の 500 で「多元現実」または「Plural Reality」を組む（HP ヘッダーと同じ方式）。「P」の四角などの仮ロゴは使わない。

## 5. 表記規約（要点）

全文は `style-guide.md`。迷ったらそちらが正。

- 会社名: 和文の法人名は **合同会社多元現実**、英文は **Plural Reality LLC**。本文の略称は「多元現実」「Plural Reality」。© は `© 2026 Plural Reality LLC`（年は発行年）。
- 製品名: **倍速会議**（Baisoku Kaigi）と **倍速アンケート**（Baisoku Survey）の2つだけ。千人会議・倍速商談・マンション版は「倍速会議の活用シーン」。Cartographer・Sonar は社内コードネームなので対外物に出さない。
- 日付: 本文は `2026年10月1日`、範囲は `2025年9月〜12月`、データ・メタは ISO `2026-10-01`。
- 数値: 数えられる実績だけ実数で書き、図表の直下に `出典：…（年）` を置く。出典のない率は書かない。
- 図表: `図1　タイトル`（図は下、表は上）。本文から番号で参照する。
- 機密区分: `社外秘` / `先方限り（…）` / 表示なし（公開）。英字の CONFIDENTIAL は使わない。
- URL: Vercel のデプロイ URL やプレビュー URL を対外物に載せない。

## 6. lint

```bash
python3 ~/.claude/skills/plural-reality-design-system/scripts/brand-lint <file-or-dir>...
python3 .../brand-lint --summary .            # rule ごとの件数だけ
python3 .../brand-lint --format json . > brand-lint.json
python3 .../brand-lint --selftest
```

法人名の誤記、旧・退役製品名、非本番 URL、半角カナ、廃止色 hex（teal 系）、Tailwind の teal クラスを検出し、1件でもあれば終了コード 1 を返す。抑止と allowlist は `style-guide.md` §9 とスクリプトの `--help`。
成果物を渡す前に必ず実行する。

## 7. 移行状況（2026-10-01）

| 対象 | 状態 |
|---|---|
| この skill と design-format-* | `tokens.css` 参照に移行済み |
| HP（`plural-reality/website`） | 未移行。`client/src/index.css` に teal と Public Sans が残る（E1 で別 PR） |
| 旧 `examples/*.html` プレビュー | この版には含めない。teal・Public Sans・誤った法人名を含むため、`tokens.css` から作り直すまで参照しない |
| Drive「デザインシステム」 | 旧版のまま。INDEX 冒頭に「正本は skill」と書く作業が残る |
