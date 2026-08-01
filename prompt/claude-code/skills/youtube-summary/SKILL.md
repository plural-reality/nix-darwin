---
name: youtube-summary
description: >
  YouTube の URL を投げるだけで、字幕を取得→日本語で要約→(関連する既存文脈があれば)Takaの状況に最適化した
  「俺の場合」節を足して Scrapbox に追記する。トリガー: YouTube URL の貼り付け + 「まとめて/要約して/scbに/メモっといて」、
  「この動画まとめて」「/youtube-summary <url>」「/yt <url>」。複数 URL 同時可。
---

# YouTube Summary → Scrapbox

YouTube URL → 字幕抽出 → 日本語要約 → Scrapbox 追記 を1コマンドで回すスキル。
API キー不要（`yt-dlp` が字幕トラックを直接引く）。字幕が無い動画のみ非対応。

**責務分離**（この repo の設計思想どおり）:
- 抽出ロジック（純粋フィルタ `url -> text`）= `yt-transcript.sh`
- 要約・パーソナライズ・書き込みの wiring = この SKILL.md（LLM が実行）
- Scrapbox 書き込みの規約 = `save-to-scrapbox` スキルが canonical（ここで再定義しない）

---

## Flow

### Step 1: トランスクリプト抽出（各 URL）

```bash
SKILL_DIR="$HOME/.claude/skills/youtube-summary"   # symlink 先。実体は nix canonical
bash "$SKILL_DIR/yt-transcript.sh" "<url>" > "$SCRATCH/yt-<id>.txt"
# タイトル/投稿者も取る（ページ見出し用）
yt-dlp --no-update --skip-download --print "%(title)s :: %(uploader)s :: %(duration_string)s" "<url>"
```

- `$SCRATCH` = セッションの scratchpad ディレクトリ。トランスクリプトは長いので**ファイルに落として Read で読む**（会話に生ダンプしない）。
- 手動字幕(en/ja)優先・無ければ自動字幕にフォールバック。両方無ければ exit 3 → その旨をユーザーに伝えて終了（音声書き起こしは別手段）。
- 複数 URL は各々抽出してから、1ページにまとめて要約する。

### Step 2: 要約（日本語・構造化）

Read でトランスクリプトを読み、**具体的な数字・固有名詞・章立てを保った**日本語要約にする。`natural-writing` の文体ルール（短文・具体・AIスロップ回避）に従う。

- 動画1本ごとに「概要1〜2文 + 要点の箇条書き（各項目は動画内の具体値つき）」。
- 冗長な逐語は捨て、意思決定に効く情報（数値・条件・結論・反例）を残す。

### Step 3: パーソナライズ「俺の場合の最適化」（該当する時だけ）

内容が Taka の既知の文脈（トライアスロン・機材・開発・会社運営・音威子府など）に接続するなら、`scrapbox-context` / `cosense-fetch -s` で関連ページを 1〜2 本引き、**Taka の状況に落とした優先順位つきの実行節**を足す。

- 例（トライアスロン動画）: 所有機材（Trek Madone・DHバー等）・弱点・次レース・過去の失敗を踏まえ、費用対効果順に「やること／やらないこと」を出す。
- 一般論で終わらせない。動画の主張 × Taka の具体状況 の交点だけを書く。
- 文脈が無い / 接続しないテーマ（純粋な技術解説等）なら、この節は**省略**して素の要約だけにする。過剰に紐づけない。

### Step 4: Scrapbox 追記

`save-to-scrapbox` の規約に厳密に従う（**新規孤立ページを作らない**が第一原則）:

1. 書く前に `scrapbox-context` で関連既存ページを検索。同じトピックのページがあれば `--prepend` で追記。
2. 新規ページが必要なら、既存の関連ページに `[新ページ名]` の足場を作る or `from [関連ページ]` 行で graph に接続してから書く。
3. **provenance 必須**: 冒頭に元の YouTube URL を `[<url> <動画タイトル>]` 形式で置く。
4. LLM が書いた本文なので `scrapbox-write`（`-g` 既定=グレー装飾ON）で書く。人間が承認/編集して昇格させる前提。

```bash
scrapbox-write --title "<ページ名>" -p <tkgshn-private|plural-reality|takalog> --dry-run < body.txt  # 確認
scrapbox-write --title "<ページ名>" -p <project>            < body.txt                                 # 書き込み
```

- 書き込み先の判断: 個人の趣味・学習 → `tkgshn-private` / 法人プロダクト・業務知識 → `plural-reality` / 最機密・人物 → `takalog`。
- 書き込み後は URL が返る。必要なら `cosense-fetch` で再取得して検証。

---

## 参照実装

トライアスロン動画2本を要約した実例:
[バイク機材でタイムを削る（マージナルゲイン）](https://scrapbox.io/tkgshn-private/バイク機材でタイムを削る（マージナルゲイン）)
— 動画要約 + 「俺の場合の最適化」+「やらないこと」の3部構成。

## 落とし穴

- `--convert-subs srt` は ffmpeg 依存で `--quiet` 下に静かに失敗する → 抽出は **VTT を直接パース**している（変更しない）。
- 自動字幕は rolling-window で逐語が一部重複する。連続重複は畳むが完全ではない。要約時にノイズとして無視すればよい。
- `yt-dlp` が古いと bot 判定で失敗しうる。失敗したら `nix flake update` で更新（nix 管理）。
