# 鉄則1: 型システムを限界まで押し上げる

## Phantom Types — 型レベルの状態マシン

Phantom Type（幽霊型）とは、型パラメータとして宣言されるが、実行時のデータ表現には一切影響しない型引数。Haskellでは`newtype Tagged tag a = Tagged a`として自然に表現される。Swiftではジェネリクスとケースなしenumを組み合わせて実現する。

**鉄則：ドメインの状態遷移は型で表現せよ。ランタイムのバリデーションを型レベルに引き上げよ。**

```swift
// ケースなしenumをPhantom Typeタグとして使用（インスタンス化不可能）
enum Validated {}
enum Unvalidated {}

struct EmailAddress<State> {
    let rawValue: String
}

// バリデーション関数：Unvalidated → Validated への遷移を型で表現
func validate(_ email: EmailAddress<Unvalidated>) -> EmailAddress<Validated>? {
    guard email.rawValue.contains("@") else { return nil }
    return EmailAddress<Validated>(rawValue: email.rawValue)
}

// バリデーション済みのメールアドレスのみ送信可能
func sendEmail(to address: EmailAddress<Validated>) {
    print("Sending to \(address.rawValue)")
}

let raw = EmailAddress<Unvalidated>(rawValue: "test@example.com")
// sendEmail(to: raw)  // ❌ コンパイルエラー！
if let valid = validate(raw) {
    sendEmail(to: valid) // ✅ OK
}
```

### 条件付きextensionで状態別メソッドを定義

```swift
enum Locked {}
enum Unlocked {}

struct Document<State> {
    let content: String
}

extension Document where State == Locked {
    func unlock(password: String) -> Document<Unlocked>? {
        guard password == "secret" else { return nil }
        return Document<Unlocked>(content: content)
    }
}

extension Document where State == Unlocked {
    func save() { print("保存完了") }
}
```

---

## Tagged/Newtypeパターン — swift-tagged

Haskellの`newtype`はゼロコストの型ラッパー。Swiftにはネイティブのnewtype機構がないため、pointfree/swift-taggedライブラリがこの空白を埋める。

**鉄則：同じ基底型を持つが意味的に異なる値は、必ずTagged型で区別せよ。**

```swift
import Tagged

struct User {
    let id: Id
    let email: Email
    let subscriptionId: Subscription.Id?
    
    typealias Id = Tagged<User, Int>
    typealias Email = Tagged<(User, email: ()), String>
}

struct Subscription {
    let id: Id
    typealias Id = Tagged<Subscription, Int>
}

func fetchSubscription(byId id: Subscription.Id) -> Subscription? { /* ... */ }

let user = User(id: 1, email: "blob@pointfree.co", subscriptionId: 1)
// fetchSubscription(byId: user.id)  // ❌ コンパイルエラー！型が違う
```

### swift-taggedのメリット

- **リテラル表現の継承**: `User(id: 1, email: "blob@pointfree.co")`のようにラッピング不要
- **数値演算の自動導出**: 条件付き適合によりTagged数値型は`+`、`-`等を自動取得
- **Codable/Equatable/Hashable**: 基底型から自動継承

### 単位系の安全性

```swift
enum SecondsTag {}
typealias Seconds<RawValue> = Tagged<SecondsTag, RawValue>

enum MillisecondsTag {}
typealias Milliseconds<RawValue> = Tagged<MillisecondsTag, RawValue>

// 異なる単位の混同はコンパイルエラー
```

---

## Result型とNever型の高度な活用

SwiftのNever型はケースを持たないenum（uninhabited type）であり、型理論におけるボトム型（⊥）に対応する。Haskellの`Void`（空の型）に相当。

```swift
// Result<Value, Never> — 絶対に失敗しない操作
let infallible: Result<String, Never> = .success("Hello")

extension Result where Failure == Never {
    var value: Success {
        switch self {
        case .success(let value): return value
        // .failureケースは不要 — Neverは構築不可能
        }
    }
}
```

### Void vs Neverの本質的な違い

| 型 | 値の数 | 意味 | 用途 |
|---|--------|------|------|
| `Void` = `()` | 1つ（`()`） | 有用な値を返さない | 戻り値のない関数 |
| `Never` | 0（構築不可能） | 絶対に返らない | `fatalError`、`Result<T, Never>` |

CombineではAnyPublisher<String, Never>が「エラーが絶対に発生しないPublisher」を表現する。
