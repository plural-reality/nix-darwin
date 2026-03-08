# 鉄則8: 型安全なエラーハンドリング

## throws vs Result vs Optional の判断マトリクス

| 基準 | `throws` | `Result<T, E>` | `Optional<T>` |
|------|----------|-----------------|----------------|
| エラー情報 | 完全（do/catch） | 完全（.failure） | なし（nilのみ） |
| 合成可能性 | `do { try a(); try b() }` | `.flatMap(f).flatMap(g)` | `?.`チェイン |
| 型安全性 | 非型付き（Swift 6前） | Failure型で型付き | エラー型なし |
| 最適用途 | 同期的失敗可能操作 | 結果の保存/受渡し | 検索、「見つからない」 |

Haskellとの対応：
- `Optional` = `Maybe`
- `Result` = `Either`（パラメータ順序が逆）
- `throws` = `ExceptT`モナドの構文糖衣

---

## 使い分けの鉄則

### Optionalを使う場面
- 「見つからなかった」が唯一のエラーケース
- Dictionary/Arrayのlookup
- 型変換（`Int("abc")`）
- なぜ失敗したかが重要でない

```swift
func findUser(byId id: User.Id) -> User? { ... }
```

### throwsを使う場面
- エラーの詳細が必要
- 複数のthrows関数を連鎖させたい（do/catch）
- async/awaitとの組み合わせ
- ほとんどの同期的な失敗可能操作

```swift
func loadConfig(from path: String) throws -> Config { ... }
```

### Resultを使う場面
- 結果を保存して後で処理したい
- flatMapチェインで合成したい（Railway Oriented Programming）
- 型付きエラーが必要（Swift 6前）
- コールバックベースのAPI

```swift
func validate(_ input: String) -> Result<ValidatedInput, ValidationError> { ... }
```

---

## エラードメインモデリング

**鉄則：エラーは代数的データ型（enum + associated values）でモデリングせよ。**

```swift
// ❌ 文字列ベースのエラー
struct AppError: Error {
    let message: String  // 構造がない、網羅的チェック不可
}

// ✅ 代数的データ型でエラードメインを表現
enum AppError: Error {
    case network(NetworkError)
    case validation(ValidationError)
    case persistence(PersistenceError)
    
    enum NetworkError: Error {
        case noConnection
        case timeout(duration: TimeInterval)
        case httpError(statusCode: Int, body: Data?)
        case decodingFailed(DecodingError)
    }
    
    enum ValidationError: Error {
        case emptyField(fieldName: String)
        case tooShort(fieldName: String, minimum: Int, actual: Int)
        case invalidFormat(fieldName: String, expected: String)
    }
    
    enum PersistenceError: Error {
        case notFound(entity: String, id: String)
        case duplicateKey(entity: String, key: String)
        case migrationFailed(from: Int, to: Int)
    }
}
```

---

## Swift 6.0 Typed Throws（SE-0413）

```swift
func validate(name: String) throws(ValidationError) -> Bool {
    guard !name.isEmpty else { throw .emptyName }
    guard name.count >= 3 else { throw .nameTooShort(name.count) }
    return true
}

do {
    try validate(name: "ab")
} catch {
    // errorは自動的にValidationError型！
    switch error {
    case .emptyName: print("空です")
    case .nameTooShort(let len): print("短すぎ: \(len)")
    }
    // defaultケース不要 — 網羅的！
}
```

### 使用ガイドライン

- `throws(ConcreteError)`はモジュール内の固定されたエラードメインに限定
- ライブラリの公開APIには非型付き`throws`を推奨（将来のエラー追加に柔軟）
- `throws(Never)`は非throwingと同等 — 型システムの統一性を提供

---

## Never型によるResult安全性

```swift
// 絶対に失敗しない操作
func alwaysSucceeds() -> Result<String, Never> {
    .success("OK")
}

// .failure()は構築不可能なのでswitchで.successだけ処理すればよい
let value = alwaysSucceeds().value  // Resultの拡張で直接取得可能

// 非同期Publisherでも同様
let publisher: AnyPublisher<String, Never> = Just("Hello").eraseToAnyPublisher()
// sinkでエラーハンドリング不要
```
