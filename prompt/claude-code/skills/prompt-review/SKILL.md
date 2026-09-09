---
name: prompt-review
description: >
  AIエージェント対話履歴を分析し、技術理解度・プロンプティングパターン・AI依存度のレポートを生成する。
  トリガー: 「画面操作をCLI/MCPで見直して」「tool使用を監査して」、「プロンプトをレビューして」「対話履歴を分析して」「理解度を診断して」または /prompt-review。
  対応ツール: Claude Code, GitHub Copilot Chat, Cursor, Cline, Roo Code, Windsurf, Antigravity, Gemini CLI, OpenAI Codex, OpenCode。
allowed-tools: Read, Write, Glob, Grep, Bash, Agent
context: fork
---

# prompt-review スキル

ユーザーの過去のAIエージェント対話履歴を分析し、技術理解度・プロンプティングパターン・AI依存度を推定してレポートを生成する。

## Codexのtool使用監査（画面操作の見直し）

「直近1か月のcomputer/browser useをCLI/MCPで置換」「操作経路を自己改善」の依頼では、この分岐だけを実行する。下の汎用`collect.py`で他のAIツールやプロンプト本文まで収集しない。

1. 読むhost・Codex保存領域・時刻窓を明示する。1か月はユーザーのタイムゾーンで起点を決め、`--since`（含む）と`--until`（含まない）を固定する。現在の監査sessionを除外する。別hostの`~/.codex`を横断読出ししない。取得できたローカル履歴と、取得できないhost/期間を分ける。
2. 同梱の[scripts/tool_usage.py](scripts/tool_usage.py)の`--help`を読み、timezone付きISO時刻を渡す。既定は当該hostの`sessions`と`archived_sessions`のみ。`--root`でfixtureや許可済みの明示領域を指定できる。出力は現在の作業領域へ保存する。
3. 出力はtool名・固定された操作種別・時刻・session ID・行番号とcoverageのみ。引数、実コード、URL、title、本文、OCR、tool結果を出力しない。`functions.exec`/`node_repl`内の参照やshell中のUI語は候補であり、実行回数・失敗回数には加算しない。fork/archivedの重複はcall IDで除き、欠測・未知形式・parse errorを明示する。
4. 件数から順位をつけ、代表例に絞って元のtool callを確認する。本文/引数の追加取得は依頼で許可された対象・用途の最小範囲に限る。未許可の会話本文・私信・機微入力が必要になったときは、対象・用途・取得範囲を示して確認する。集計だけから「無駄」「置換済み」「冪等」を断定しない。
5. [browser-automationの判断表](../browser-automation/references/semantic-routing.md)で`replace`/`hybrid`/`keep_ui`/`unverified`を判定する。既存CLI/MCPが今使えるかと、当時使えたかを混同しない。
6. `self-learn`の「2-E. 画面操作から学ぶ」へ渡して正本の最小改善と検証を行う。レポートは目的・対象期間・母数・代表例のsource ID/行・判断・検証・未確認を残す。生の対話はレポートに複製しない。

## ステップ0: 使い方の案内

まず以下の使い方をユーザーに簡潔に案内してから、引数に応じた分析を自動実行する:

```
/prompt-review              # 全プロジェクト、過去7日分（デフォルト）
/prompt-review 30           # 過去30日分
/prompt-review cartographer # 特定プロジェクトのみ
/prompt-review cartographer 30 # 特定プロジェクト × 過去30日分
/prompt-review 0            # 全期間
```

レポートは `~/Developer/claude-code-analytics/reports/prompt-review-YYYY-MM-DD.md` に出力される。

案内後、引数があればその条件で、なければデフォルト（過去7日）で分析を開始する。

## 引数の処理

`$ARGUMENTS` を解析し、以下のルールで引数を処理する:

- 引数なし → 全プロジェクト横断、過去7日分（デフォルト）
- 数値のみ → **日数フィルタ**（例: `30` → 過去30日分）
- `all` または `0` → **全期間**（日数フィルタなし）
- 文字列のみ → **プロジェクト名フィルタ**（部分一致）
- 文字列 + 数値 → **プロジェクト名** + **日数フィルタ**（例: `yonshogen 30`）

## ステップ1: データ収集（スクリプト実行）

前処理スクリプト [scripts/collect.py](scripts/collect.py) を実行してデータを収集する。
このスクリプトは Claude Code, GitHub Copilot Chat, Cursor, Cline, Roo Code, Windsurf, Antigravity, Gemini CLI, OpenAI Codex, OpenCode の
ログを自動検出し、フィルタ済みのJSON を標準出力に返す。

### 引数からスクリプトオプションを組み立てる

`$ARGUMENTS` を解析し、Bash で以下のように実行する。
**実行前にタイムスタンプ付きのファイル名を生成し、スクリプト出力の保存先と Read の参照先で同じパスを使うこと。**

```bash
OUTFILE="/tmp/prompt-review-data_$(date +%Y%m%d%H%M%S).json"
python ~/.claude/skills/prompt-review/scripts/collect.py [OPTIONS] > "$OUTFILE"
```

- 引数なし → オプションなし（デフォルト: 過去7日分）
- 数値のみ（例: `30`） → `--days 30`
- `all` または `0` → `--days 0`（全期間）
- 文字列のみ（例: `yonshogen`） → `--project yonshogen`
- 文字列 + 数値（例: `yonshogen 30`） → `--project yonshogen --days 30`

**重要**: スクリプトのパスは、このスキルファイルからの相対パスではなく、スキルが格納されているプロジェクトの `.claude/skills/prompt-review/scripts/collect.py` の絶対パスを使うこと。現在の作業ディレクトリ（`cwd`）を基準に `.claude/skills/prompt-review/scripts/collect.py` を指定する。

### 出力の読み取り

スクリプト実行後、上記で生成した `$OUTFILE` のパスを Read で読み込む。

出力JSON構造:
```json
{
  "summary": {
    "total_messages": 2616,
    "detected_tools": ["Claude Code", "GitHub Copilot Chat"],
    "filter_days": null,
    "filter_project": null
  },
  "sources": [
    {
      "tool": "Claude Code",
      "status": "検出",
      "messages": [
        {"text": "プロンプト本文", "timestamp": "2025-09-29 03:16", "project": "yonshogen"}
      ],
      "period": "2025-09-29 03:16 〜 2026-03-12 04:58"
    }
  ],
  "project_stats": {
    "farbrain": {"count": 668, "tools": ["Claude Code"]},
    "yonshogen": {"count": 215, "tools": ["Claude Code"]}
  },
  "secret_warnings": [
    {
      "tool": "Claude Code",
      "project": "some-project",
      "timestamp": "2025-10-01 12:00",
      "type": "OpenAI API Key",
      "masked_value": "sk-abc12***xyz9",
      "prompt_excerpt": "APIキーはsk-abc123..."
    }
  ]
}
```

## ステップ2: 分析

Read で `$OUTFILE`（ステップ1で生成したタイムスタンプ付きファイル）を読み込んだら、以下の観点で `messages` 配列内のユーザープロンプトを分析する。各観点について**具体的なエビデンス**（実際のプロンプト断片の引用）を必ず含めること。

### 前処理: プロジェクト別サマリーの作成と短文応答の除外

まず `project_stats` を使ってプロジェクト別のメッセージ数・使用ツールの一覧を把握する。
各プロジェクトのプロンプト内容を読み、そのプロジェクトで行われている作業内容を1行で要約する。
この情報はレポートの「2. プロジェクト別サマリー」セクションに出力する。

次に、短文の肯定応答を分析対象から除外する。

### 前処理: 短文の肯定応答を無視する

Claude Code はユーザーに「〜しますか？」と確認を求めることが多く、それに対するユーザーの短い肯定応答はプロンプティング能力や技術理解度の分析に価値がない。以下のようなメッセージは分析対象から**除外**すること:

- 単純な肯定: 「y」「yes」「はい」「うん」「ok」「sure」「yep」「yeah」
- 実行指示: 「進めて」「やって」「do it」「doit」「go」「go ahead」「proceed」
- 承認: 「それで」「それでいい」「それでお願いします」「お願いします」「いいよ」「いいです」「大丈夫」
- 感謝のみ: 「ありがとう」「ありがとうございます」「thanks」「thx」

**判定基準**: メッセージが短文（概ね20文字以下）で、上記のパターンに該当するもの。ただし、短文でも具体的な技術指示を含むもの（例:「30pxがいいです」「asyncで」）は除外しない。

### 2a. 技術的理解度マップ

プロンプトから言及されている技術概念を抽出し、3段階に分類:
- **熟知**: 自信を持って指示、正確な用語使用、具体的な実装方針の提示
- **基本理解**: 概念は知っているが詳細はAIに委任
- **学習中/曖昧**: 質問形式、誤解がある、試行錯誤が多い

分類のシグナル:
- 命令形で具体的な指示 → 熟知
- 「〜してください」＋概念名のみ → 基本理解
- 「〜って何？」「〜がうまくいかない」「どうすればいい？」 → 学習中

### 2b. プロンプティングパターン分析

- **効果的なパターン**: 具体的な制約指定、段階的な指示、十分なコンテキスト提供、期待する出力形式の明示
- **改善可能なパターン**: 曖昧な指示（「いい感じにして」等）、コンテキスト不足、目的と手段の混同
- **特徴的な癖**: 短い承認（「y」「doit」等）の頻度、日本語/英語の使い分け

### 2c. AI依存度分析

プロジェクト・ツールごとに:
- ユーザーが方針を決定しAIに実装を任せているケース（主体的）
- AIに方針決定から任せているケース（依存的）
- デバッグ/エラー解決でAIに頼るパターン
- 状態確認を頻繁にAIに依頼するパターン（「状況確認して」等）

### 2d. 成長の軌跡

時系列で:
- プロンプトの質・具体性の変化
- 新しく使い始めた技術概念
- 繰り返し発生する課題パターン

### 2e. プロジェクト横断・ツール横断の傾向

- 得意領域と不得意領域
- プロジェクト種類による振る舞いの違い
- AIツールの使い分け方（検出されたツールが複数の場合）

### 2f. シークレット・クレデンシャル警告

`secret_warnings` 配列が空でない場合、レポートの冒頭（データソースサマリーの直後）に警告セクションを出力する。
スクリプトが検出した API Key、Token、Password、接続文字列等のシークレットを一覧で表示し、
ユーザーに対してキーのローテーション（再発行・無効化）を推奨する。

**レポート内ではシークレットの値は絶対に平文で書かない**。スクリプトがマスク済みの値（`masked_value`）を返すので、それをそのまま使う。

## ステップ3: レポート生成

[references/report-template.md](references/report-template.md) のテンプレートに従い、日本語でレポートを生成する。

### 出力ルール

1. `~/Developer/claude-code-analytics/reports/` ディレクトリが存在しない場合は Bash で `mkdir -p ~/Developer/claude-code-analytics/reports` を実行
2. Write ツールを使って `~/Developer/claude-code-analytics/reports/prompt-review-YYYY-MM-DD.md` に書き出す（YYYYMMDDは実行日）
3. レポート生成後、ファイルパスをユーザーに通知する

### 記述上の注意

- レポートは**必ず日本語**で出力すること
- 推測は「〜と推測されます」「〜の可能性があります」と明示すること
- プロンプトの原文を引用する場合は**短く切り取り**、プライバシーに配慮すること
  - ファイルパスの個人名部分は `<user>` にマスク
  - プロジェクト固有の機密情報は伏せる
- 分析できなかった部分は「データ不足のため分析できませんでした」と正直に記載
- どのツールからの情報かを括弧書きで明記する（例:「(Claude Code)」「(Copilot Chat)」）
- エビデンスのないセクションは省略してよい

## 参照リソース

- **[scripts/collect.py](scripts/collect.py)** — データ収集・前処理スクリプト（Python）
- **[references/data-sources.md](references/data-sources.md)** — 各AIツールのログ保存場所・形式の詳細
- **[references/report-template.md](references/report-template.md)** — レポートの構造テンプレート
