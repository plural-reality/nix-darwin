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

**まず Codex の生出力を verbatim で提示する**(要約で置き換えない)。実装者(Claude)が敵の判決を要約すると論点が無意識に軟化するため、原文を残してから分析を重ねる:

```
## Codex Review (raw)
(Codex の出力をそのまま。指摘本文は削らない)

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

原則は `codex review` の再実行で済ます(固定ハーネス＝Claude が敵対フレームを軟化できない)。`codex review` で届かない特定論点だけ `codex exec` を使い、**下記の refute プレフィックスを verbatim で前置する**(Claude が毎回敵対スタンスを書き換えないため):

```bash
codex exec --full-auto "あなたはこの変更の実装者ではなくレビュアーです。デフォルトで『この実装は壊れている／この主張は誤り』と仮定し、反証を試みてください。確信が持てなければ「問題あり」側に倒す。検証対象: <specific question> / <context>" 2>&1
```

### Step 5: 修正の実行

ユーザーが同意した修正を実行する。Codex の提案と Claude の判断を統合して、最適な修正を適用する。

## 敵対性の規律 (なぜこの形か)

- **独立性は `codex review` の時点で既に担保**されている: 別プロセス・別モデル・read-only fresh context。敵対レビューが要求する「実装者の前提を継承しない他者」はここで満たされる。これ以上の機構で独立性は上乗せされない。
- **残る唯一のバイアス面 = 実装者(Claude)が敵を枠づけ／判決を要約すること**。対策は2つだけ: ①Codex の生出力を出す(Step 3) ②敵対プロンプトを固定し Claude に書き換えさせない(Step 4)。

## agmsg にエスカレーションする境界

このskillで完結するのは**単発の diff レビュー**。レビューが「1つの設計を多ターンで殴り合う」フェーズに変わった時だけ、agmsg(別人格・永続スレッド・モデル多様性・権限/マシン分離)へ移す。理由: stateless な `codex exec` の繰り返しは毎ラウンド Claude が状態を再要約(lossy)し毎回枠づけるため、長期論戦では不利。逆に単発レビューに agmsg を足すのは spawn層+messaging層+統合層の概念過剰で、独立性を1つも上乗せしない。

## Important Notes

- Codex の出力が空または認証エラーの場合は、`codex login` を案内する
- レビュー結果は必ずユーザーに提示してから修正に入る（勝手に直さない）
- CLAUDE.md の関数型プログラミング規約に基づいてレビュー判断を行う
