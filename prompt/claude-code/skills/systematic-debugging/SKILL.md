---
name: systematic-debugging
description: >
  バグ、テスト失敗、予期しない動作に遭遇した際に、修正を提案する前に使用する。
  トリガー: テスト失敗、本番バグ、ビルドエラー、パフォーマンス問題、
  「なぜ動かない」「原因がわからない」「修正したのにまた壊れた」
---

# Systematic Debugging

## Overview

ランダムな修正は時間を浪費し、新しいバグを生む。クイックパッチは根本問題を隠す。

**Core principle:** 修正を試みる前に、必ず根本原因を特定せよ。症状の修正は失敗である。

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Phase 1 を完了していない場合、修正を提案してはならない。

## When to Use

あらゆる技術的問題に使用:
- テスト失敗
- 本番バグ
- 予期しない動作
- パフォーマンス問題
- ビルドエラー
- インテグレーション問題

**特に以下の場合:**
- 時間的プレッシャーがある（緊急時ほど推測に走りがち）
- 「ちょっとした修正」が明らかに見える
- 既に複数の修正を試した
- 前回の修正が効かなかった

## The Four Phases

各フェーズを完了してから次へ進むこと。

### Phase 1: Root Cause Investigation

**修正を試みる前に:**

1. **エラーメッセージを丁寧に読む**
   - エラーやワーニングを飛ばさない
   - スタックトレースを完全に読む
   - 行番号、ファイルパス、エラーコードを記録

2. **再現性を確認**
   - 確実にトリガーできるか？
   - 正確な手順は？
   - 毎回発生するか？
   - 再現できない場合 → データを集める、推測しない

3. **最近の変更を確認**
   - `git diff`、最近のコミット
   - 新しい依存関係、設定変更
   - 環境の差異

4. **マルチコンポーネントシステムでの証拠収集**

   複数コンポーネントがある場合、修正前に診断用計測を追加:
   ```
   各コンポーネント境界で:
     - 入力データをログ
     - 出力データをログ
     - 環境/設定の伝播を検証
     - 各レイヤーの状態を確認

   1回実行して「どこで壊れるか」の証拠を収集
   → 証拠を分析して故障コンポーネントを特定
   → そのコンポーネントを調査
   ```

5. **データフローをトレース**

   エラーがコールスタックの深い位置にある場合:
   - 不正な値はどこで発生したか？
   - 誰がこの不正な値で呼び出したか？
   - ソースまで遡り続ける
   - **ソースで修正する、症状では修正しない**

### Phase 2: Pattern Analysis

**修正の前にパターンを見つける:**

1. **動作する類似コードを探す**
   - 同じコードベース内で似た動作コードを見つける
   - 壊れているものと似ていて動くものは何か？

2. **リファレンスと比較**
   - パターンを実装している場合、参照実装を完全に読む
   - 流し読みしない — 全行読む

3. **差異を特定**
   - 動作するものと壊れているものの違いは？
   - 全ての差異をリスト化（些細なものも含む）
   - 「それは関係ないだろう」と決めつけない

### Phase 3: Hypothesis and Testing

**科学的方法:**

1. **単一の仮説を立てる**
   - 明確に述べる: 「XがYの理由で根本原因だと考える」
   - 書き出す、具体的に

2. **最小限のテスト**
   - 仮説を検証する最小の変更を行う
   - 一度に一つの変数だけ
   - 複数の修正を同時にしない

3. **続行前に検証**
   - 動いた？ → Phase 4 へ
   - 動かない？ → 新しい仮説を立てる
   - 上に追加の修正を積まない

### Phase 4: Implementation

**症状ではなく根本原因を修正:**

1. **失敗するテストケースを作成**
   - 最もシンプルな再現
   - 自動テストが望ましい
   - 修正前に必ず用意

2. **単一の修正を実装**
   - 特定した根本原因に対処
   - 一度に一つの変更
   - 「ついでに」改善しない

3. **修正を検証**
   - テストが通るか？
   - 他のテストが壊れていないか？
   - 問題が実際に解決したか？

4. **修正が効かない場合**
   - **停止**
   - 何回修正を試みたか数える
   - 3回未満: Phase 1 に戻り、新情報で再分析
   - **3回以上: アーキテクチャ自体を疑え（下記参照）**

5. **3回以上の修正が失敗: アーキテクチャを疑う**

   アーキテクチャ問題の兆候:
   - 各修正が異なる場所で新たな共有状態/結合/問題を発見
   - 修正に「大規模リファクタリング」が必要
   - 各修正が別の場所で新たな症状を生む

   **基本に立ち返る:**
   - このパターンは根本的に健全か？
   - 惰性で続けていないか？
   - 症状修正を続けるより、アーキテクチャをリファクタすべきか？

   **さらなる修正を試みる前に、ユーザーと議論する**

## Red Flags - STOP and Follow Process

以下のように考えていたら:
- 「とりあえず今は応急処置、後で調査」
- 「Xを変えてみて動くか見よう」
- 「複数変更入れてテスト実行」
- 「テストはスキップ、手動で確認」
- 「多分Xだろう、直そう」
- 「完全には理解してないけどこれで動くかも」
- 「もう1回修正を試そう」(既に2回以上試した後)

**全て: 停止。Phase 1 に戻る。**

## Supporting Techniques

### Root Cause Tracing (コールスタック逆追跡)

バグがスタックの深い位置に現れる場合:
1. 症状を観察
2. 直接原因を見つける
3. 「誰がこれを呼んだ？」を問う
4. 上位へトレースし続ける
5. 元のトリガーを見つける → ソースで修正

手動トレースできない場合はスタックトレース計測を追加:
```typescript
const stack = new Error().stack;
console.error('DEBUG:', { directory, cwd: process.cwd(), stack });
```

### Defense-in-Depth (多層バリデーション)

根本原因を修正した後、データが通過する全レイヤーでバリデーション:

| Layer | Purpose | Example |
|-------|---------|---------|
| Entry Point | 明らかに不正な入力を拒否 | 空文字列チェック、存在確認 |
| Business Logic | データがこの操作に妥当か確認 | 必須パラメータ検証 |
| Environment Guard | 特定コンテキストでの危険操作を防止 | テスト時のtmpdir外gitInit拒否 |
| Debug Instrumentation | フォレンジック用コンテキスト記録 | ログ + スタックトレース |

単一バリデーション: 「バグを直した」
多層バリデーション: 「バグを構造的に不可能にした」

### Condition-Based Waiting (条件ベース待機)

任意の `sleep`/`setTimeout` を条件ポーリングに置換:

```typescript
// BAD: タイミングの推測
await new Promise(r => setTimeout(r, 50));

// GOOD: 条件の待機
const waitFor = async <T>(
  condition: () => T | undefined | null | false,
  description: string,
  timeoutMs = 5000
): Promise<T> => {
  const startTime = Date.now();
  const poll = (): Promise<T> => {
    const result = condition();
    return result ? Promise.resolve(result)
      : Date.now() - startTime > timeoutMs
        ? Promise.reject(new Error(`Timeout: ${description} after ${timeoutMs}ms`))
        : new Promise(r => setTimeout(r, 10)).then(poll);
  };
  return poll();
};
```

### Find Polluter (テスト汚染の二分探索)

どのテストが不要なファイル/状態を生成しているか特定:
```bash
#!/usr/bin/env bash
# Usage: ./find-polluter.sh <file_to_check> <test_pattern>
# Example: ./find-polluter.sh '.git' 'src/**/*.test.ts'
set -e
POLLUTION_CHECK="$1"; TEST_PATTERN="$2"
for TEST_FILE in $(find . -path "$TEST_PATTERN" | sort); do
  [ -e "$POLLUTION_CHECK" ] && { echo "Pollution exists before: $TEST_FILE"; continue; }
  npm test "$TEST_FILE" > /dev/null 2>&1 || true
  [ -e "$POLLUTION_CHECK" ] && { echo "FOUND POLLUTER: $TEST_FILE"; exit 1; }
done
echo "No polluter found"
```

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| **1. Root Cause** | エラー読解、再現、変更確認、証拠収集 | WHAT と WHY を理解 |
| **2. Pattern** | 動作例の発見、比較 | 差異を特定 |
| **3. Hypothesis** | 仮説立案、最小テスト | 確認または新仮説 |
| **4. Implementation** | テスト作成、修正、検証 | バグ解決、テスト通過 |

## Real-World Impact

- 体系的アプローチ: 15-30分で修正
- ランダム修正: 2-3時間のスラッシング
- 初回修正成功率: 95% vs 40%
- 新バグ混入: ほぼゼロ vs 頻発

---
*Based on [obra/superpowers](https://github.com/obra/superpowers) systematic-debugging skill, adapted for this environment.*
