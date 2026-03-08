# 鉄則7: パターンマッチングと網羅性

## defaultケースの禁止

**鉄則：enumのswitchでは`default`を使うな。全ケースを明示的に列挙せよ。**

```swift
enum PaymentMethod {
    case creditCard
    case debitCard
    case cash
}

// ✅ 網羅的 — 新しいケース追加時にコンパイラが全箇所を検出
switch method {
case .creditCard: handleCredit()
case .debitCard:  handleDebit()
case .cash:       handleCash()
}

// ❌ defaultが新しいケースを隠蔽
switch method {
case .creditCard: handleCredit()
default: handleOther()  // case .cryptocurrency追加時も警告なし！
}
```

後から`case cryptocurrency`を追加した場合：
- 網羅的switch → 全箇所でコンパイルエラー（完璧な検出）
- default使用 → 静かに通過（バグの温床）

Haskellの`-Wall`による非網羅的パターンマッチ警告と同じ原理。ただしSwiftではエラーとして強制される点がより強力。

---

## @unknown default

外部ライブラリの非凍結enum（将来ケースが追加される可能性がある）に対してのみ使用。

```swift
switch authStatus {
case .notDetermined: requestPermission()
case .authorized: proceed()
case .denied: showSettingsPrompt()
@unknown default: handleUnknownCase()
// 新しい既知ケースが追加されると警告を生成
}
```

`@unknown default`は通常の`default`と異なり、新しいケースが追加されると警告を出す。自分で定義したenumには不要。

---

## ネストされたパターンマッチング

```swift
enum AppError: Error {
    case network(NetworkError)
    case database(DatabaseError)
    
    enum NetworkError: Error {
        case noConnection
        case timeout(seconds: Int)
        case httpError(statusCode: Int, body: Data?)
    }
    
    enum DatabaseError: Error {
        case notFound(entity: String, id: String)
        case corrupted
    }
}

// 深いネストもコンパイラが網羅性を検証
switch error {
case .network(.noConnection):
    showOfflineUI()
case .network(.timeout(let secs)) where secs > 30:
    showLongTimeoutError()
case .network(.timeout):
    showTimeoutError()
case .network(.httpError(401, _)):
    promptLogin()
case .network(.httpError(let code, _)):
    showHTTPError(code)
case .database(.notFound(let entity, let id)):
    log("Missing \(entity): \(id)")
case .database(.corrupted):
    showCorruptionAlert()
}
```

---

## guard case / if case

enumの特定ケースだけをチェックしたい場合に使用。

```swift
enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
}

// guard case — 早期リターンパターン
func handleLoaded(_ state: LoadingState<User>) -> User? {
    guard case .loaded(let user) = state else { return nil }
    return user
}

// if case — 条件分岐
if case .failed(let error) = state {
    showError(error)
}

// for case — コレクションからのフィルタリング
let states: [LoadingState<User>] = [...]
for case .loaded(let user) in states {
    print(user.name)  // loadedケースのみ抽出
}
```

---

## Swift 5.9 switch式

switchが式として値を返せる。

```swift
let statusMessage = switch state {
case .idle: "待機中"
case .loading: "読み込み中..."
case .loaded(let data): "完了: \(data.count)件"
case .failed(let error): "エラー: \(error.localizedDescription)"
}

// SwiftUIのViewビルダー内でも有用
var body: some View {
    let color = switch priority {
    case .high: Color.red
    case .medium: Color.orange
    case .low: Color.green
    }
    Text(title).foregroundColor(color)
}
```
