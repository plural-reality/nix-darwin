---
name: tdd
description: >
  機能実装やバグ修正の際に、実装コードを書く前に使用する。
  RED-GREEN-REFACTOR サイクルを強制する。
  トリガー: 新機能実装、バグ修正、リファクタリング、動作変更、
  「テスト書いて」「TDDで」「テストファースト」
---

# Test-Driven Development (TDD)

## Overview

テストを先に書く。失敗を確認する。最小のコードで通す。

**Core principle:** テストが失敗するのを見なかったなら、そのテストが正しいものをテストしているかわからない。

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

テスト前にコードを書いた？ **削除しろ。最初からやり直せ。**

例外なし:
- 「参考」として残さない
- 「適応」しながらテストを書かない
- 見ない
- 削除は削除

## Red-Green-Refactor

### RED - 失敗するテストを書く

1つの振る舞いを示す最小限のテストを書く。

```typescript
// GOOD: 明確な名前、実際の振る舞いをテスト、1つのこと
test('retries failed operations 3 times', async () => {
  const attempts = { count: 0 };
  const operation = () => {
    attempts.count++;
    return attempts.count < 3
      ? Promise.reject(new Error('fail'))
      : Promise.resolve('success');
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts.count).toBe(3);
});
```

```typescript
// BAD: 曖昧な名前、モックの動作をテスト
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(2);
});
```

要件:
- 1つの振る舞い
- 明確な名前（名前に "and" があれば分割せよ）
- 実際のコード（モックは不可避な場合のみ）

### Verify RED - 失敗を確認

**必須。絶対にスキップしない。**

```bash
npm test path/to/test.test.ts
```

確認:
- テストが失敗する（エラーではなく失敗）
- 失敗メッセージが期待通り
- 機能が未実装だから失敗する（タイポではなく）

**テストが通った？** 既存の動作をテストしている。テストを修正。

### GREEN - 最小のコードで通す

テストを通す最もシンプルなコードを書く。

```typescript
// GOOD: 通すのに十分なだけ
const retryOperation = <T>(fn: () => Promise<T>): Promise<T> =>
  fn().catch(() => fn().catch(() => fn()));
```

```typescript
// BAD: 過剰設計 (YAGNI)
const retryOperation = <T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> => { /* ... */ };
```

テスト以上の機能を追加しない、他のコードをリファクタしない。

### Verify GREEN - 成功を確認

**必須。**

```bash
npm test path/to/test.test.ts
```

確認:
- テストが通る
- 他のテストも通る
- 出力がクリーン（エラー、ワーニングなし）

### REFACTOR - クリーンアップ

GREEN の後のみ:
- 重複を除去
- 名前を改善
- ヘルパーを抽出

テストをグリーンに保つ。振る舞いを追加しない。

### Repeat

次の機能のために次の失敗テスト。

## Testing Anti-Patterns

### 1. モックの動作をテストする
```typescript
// BAD: モックが存在することをテスト
expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();

// GOOD: 実際のコンポーネントの振る舞いをテスト
expect(screen.getByRole('navigation')).toBeInTheDocument();
```

### 2. 本番コードにテスト専用メソッドを追加
```typescript
// BAD: テストでしか使わない destroy()
class Session { async destroy() { /* ... */ } }

// GOOD: テストユーティリティに分離
const cleanupSession = async (session: Session) => { /* ... */ };
```

### 3. 依存関係を理解せずにモック
```typescript
// BAD: テストが依存する副作用を潰してしまう
vi.mock('ToolCatalog', () => ({ discoverAndCacheTools: vi.fn() }));

// GOOD: 遅い部分だけモック、テストが必要な動作は保持
vi.mock('MCPServerManager'); // 遅いサーバー起動だけモック
```

### 4. 不完全なモック
```typescript
// BAD: 必要なフィールドの一部だけモック
const mockResponse = { status: 'success', data: { userId: '123' } };

// GOOD: 実APIの完全な構造をミラー
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' },
  metadata: { requestId: 'req-789', timestamp: 1234567890 }
};
```

### Gate Function (モック追加前)

```
モックを追加する前に:
  1. 「実メソッドにはどんな副作用がある？」
  2. 「このテストはその副作用に依存する？」
  3. 「依存する場合 → より低レベルでモックする」
  4. 「不明な場合 → まず実装で実行してから最小限のモック」
```

## Common Rationalizations

| 言い訳 | 現実 |
|--------|------|
| 「シンプルすぎてテスト不要」 | シンプルなコードも壊れる。テストは30秒。 |
| 「後でテスト書く」 | 即座に通るテストは何も証明しない。 |
| 「手動テスト済み」 | アドホック ≠ 体系的。記録なし、再実行不可。 |
| 「X時間の作業を削除するのは無駄」 | サンクコスト。検証不能なコードこそ技術的負債。 |
| 「参考として残す」 | それを見ながら書く = テスト後書き。削除は削除。 |
| 「TDDは教条的、実用的に」 | TDDこそ実用的。デバッグより速い。 |
| 「テスト後書きでも同じ目的」 | 後書き = "何をしている?" 先書き = "何をすべき?" |

## Bug Fix Example

**Bug:** 空のメールが受け入れられる

**RED:**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify RED:** `FAIL: expected 'Email required', got undefined`

**GREEN:**
```typescript
const submitForm = (data: FormData) =>
  !data.email?.trim()
    ? { error: 'Email required' }
    : processForm(data);
```

**Verify GREEN:** `PASS`

## Verification Checklist

完了前に:
- [ ] 全ての新関数/メソッドにテストがある
- [ ] 各テストが実装前に失敗するのを確認した
- [ ] 各テストが期待通りの理由で失敗した
- [ ] 各テストを通す最小限のコードを書いた
- [ ] 全テストが通る
- [ ] 出力がクリーン
- [ ] テストは実コードを使用（モックは不可避な場合のみ）
- [ ] エッジケースとエラーをカバー

全てチェックできない？ TDDをスキップした。最初からやり直せ。

---
*Based on [obra/superpowers](https://github.com/obra/superpowers) test-driven-development skill, adapted for this environment.*
