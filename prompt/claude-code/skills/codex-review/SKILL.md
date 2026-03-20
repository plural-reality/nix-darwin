---
name: codex-review
description: "Codex CLI (OpenAI) を使ったコードレビュー。Claude が Codex のレビュー結果を分析し、同意/反論/補足を付けて返す。必要なら Codex に再度質問して相互レビューする。トリガー: 「レビュー」「レビューして」「review」「コードレビュー」"
---

# Codex Cross-Review

Claude Code から OpenAI Codex CLI を呼び出し、2つのAIによる相互レビューを行う。

## Flow

### Step 1: レビュー対象の特定

引数の解釈:
- 引数なし → `codex review --uncommitted` (未コミットの変更)
- ブランチ名 → `codex review --base <branch>` (ブランチ差分)
- コミットSHA → `codex review --commit <sha>`

### Step 2: Codex Review の実行

```bash
# 未コミット変更のレビュー
codex review --uncommitted 2>&1

# ブランチ差分のレビュー
codex review --base main 2>&1

# 特定コミットのレビュー
codex review --commit <sha> 2>&1
```

タイムアウト: 300秒。Codex は OAuth 認証済み。

### Step 3: Claude による分析

Codex の出力を受け取ったら、以下の構造で分析する:

```
## Codex Review Summary
(Codexの指摘を箇条書きで要約)

## Claude's Assessment
各指摘に対して:
- **同意** — 理由と修正案
- **反論** — なぜ同意しないか、代替案
- **補足** — Codexが見逃している観点

## Action Items
(実際に修正すべき項目のリスト、優先度付き)
```

### Step 4: 深掘り (必要な場合のみ)

特定の指摘について Codex に詳細を聞きたい場合:

```bash
codex exec --full-auto "以下のコード変更について、<specific question> を詳しく分析してください: <context>" 2>&1
```

### Step 5: 修正の実行

ユーザーが同意した修正を実行する。Codex の提案と Claude の判断を統合して、最適な修正を適用する。

## Important Notes

- Codex の出力が空または認証エラーの場合は、`codex login` を案内する
- レビュー結果は必ずユーザーに提示してから修正に入る（勝手に直さない）
- CLAUDE.md の関数型プログラミング規約に基づいてレビュー判断を行う
