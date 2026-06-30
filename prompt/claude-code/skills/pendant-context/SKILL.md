---
name: pendant-context
description: "Limitless AIペンダントのライフログを検索し、ユーザーの質問に関連する会話・文脈を自動取得して回答に活用する。トリガー: 「最近話したこと」「昨日の会話」「何か約束してたっけ」「ペンダントで調べて」「ライフログ」「最近喋ったこと」など、過去の対面・音声会話の参照。"
---

# Pendant Context スキル — Limitless ライフログ検索

Limitless AIペンダントのライフログを検索し、関連コンテキストを回答に組み込む。

## ツール

```
python3 ~/.claude/scripts/pendant.py <command> [options]
```

**注意**: fish shell では `/bin/bash -c '...'` で実行すること。

## トリガー

会話・約束・人名・期間など「過去に話したこと」を参照する必要があるとき優先的に使う:

1. **最近の会話に関する質問**: 「最近〜について話した」「昨日の会話で」「誰かと〜について」
2. **約束・タスクの確認**: 「やるって言ってた」「約束してた」
3. **人名が出てきたとき**: 特定の人との会話を検索
4. **プロジェクトの文脈補強**: 最近議論した内容の確認
5. **明示的な検索依頼**: 「ペンダントで調べて」「ライフログ」「最近喋ったこと」
6. **今日/昨日/今週の振り返り**: 期間指定の会話検索

## コマンドリファレンス

### 検索（最重要・Limitless セマンティック検索）

```bash
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py -f markdown search "検索クエリ" --limit 5'
```

### 今日の会話一覧

```bash
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py -f compact today'
```

### 日付指定

```bash
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py -f markdown date 2026-02-17'
```

### 接続確認

```bash
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py config-check'
```

### データエクスポート（Limitless停止前に定期実行推奨）

```bash
# 増分エクスポート
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py export --since 2026-02-01'

# 全件エクスポート
/bin/bash -c 'python3 ~/.claude/scripts/pendant.py export-all'
```

エクスポート先: `~/.claude/data/pendant-export/limitless/YYYY-MM-DD.jsonl`

## 出力フォーマット

| フラグ | 用途 |
|---|---|
| `-f json` | デフォルト、構造化データ |
| `-f compact` | 一行サマリー、一覧表示向け |
| `-f markdown` | Claude Code への回答組み込み向け |

## 検索戦略

### ステップ1: クエリの構築

ユーザーの質問から検索キーワードを抽出する。

例:
- 「Pluralityについて最近誰かと話した？」→ `search "Plurality"`
- 「昨日のミーティングで何決めた？」→ `date 2026-02-17` + `search "meeting"`
- 「田中さんとの会話」→ `search "田中"`

### ステップ2: 検索実行

1. まず `search` で検索（Limitless のセマンティック検索が最も精度が高い）
2. 必要に応じて `date` で日付指定

### ステップ3: コンテキストの活用

- 取得した会話内容を分析し、質問に関連する部分を抽出
- 会話の文脈（誰と、いつ、何について）を明確にする

## レスポンスフォーマット

取得した情報を回答に組み込む際:

1. **出典を明示**: 「Pendant ライフログ（YYYY/MM/DD, Limitless）によると...」
2. **会話の相手を示す**: 「〜さんとの会話で...」（わかる場合）
3. **不確実性を示す**: 「〜のようです」「〜と話していたようです」

### 表示テンプレート

```
📎 **Pendant コンテキスト** (YYYY/MM/DD)
> [関連する会話の要約]
> Source: Limitless

[本題の回答]
```

## 設定

設定ファイル: `~/.config/pendant/config.toml`

```toml
limitless_api_key = "sk-..."
export_dir = "~/.claude/data/pendant-export"
timezone = "Asia/Tokyo"
```

## エラーハンドリング

- **401/403**: API キーが無効 → ユーザーに更新を依頼
- **429**: レート制限 → 少し待ってリトライ
- **空の結果**: 「関連する会話記録は見つかりませんでした」と伝え、通常通り回答

## 注意事項

- ペンダントのライフログは**極めてプライベートな情報**。第三者に共有しないこと
- 会話の全文を不必要に出力しない。関連部分のみ抽出する
- Limitless APIレート制限: 180リクエスト/分
- Limitless は 2026年後半にサービス終了予定。定期的に `export` を実行してバックアップすること
- fish shell では `/bin/bash -c` で実行すること
