# 鉄則2: Swift最新機能の活用

## Swift 5.9の革新的機能群

### マクロ（SE-0382/0389/0397）

型安全なコンパイル時コード生成。SwiftSyntax ASTに対して操作し、展開前に型チェックされる。

```swift
// @Observable マクロ — ObservableObject + @Published を置き換え
@Observable
class CounterModel {
    var count = 0        // 自動的に変更通知が生成される
    var name = "Counter"
}
```

### パラメータパック（SE-0393）

可変長ジェネリクスを実現。SwiftUIの10ビュー制限を撤廃。

```swift
func allEqual<each T: Equatable>(
    _ lhs: repeat each T, 
    _ rhs: repeat each T
) -> Bool {
    for pair in repeat (each lhs, each rhs) {
        guard pair.0 == pair.1 else { return false }
    }
    return true
}
```

### if/switch式（SE-0380）

パターンマッチングが式として値を返せる。

```swift
let medal = switch score {
    case ...300: "Bronze"
    case 301...700: "Silver"
    default: "Gold"
}

let result = if score > 500 { "Pass" } else { "Fail" }
```

### Noncopyable型（~Copyable）とOwnership（SE-0377/0390）

Haskellの線形型（LinearTypes拡張）やRustの所有権モデルに対応。

```swift
struct FileHandle: ~Copyable {
    private let fd: Int32
    
    init(path: String) { fd = open(path, O_RDONLY) }
    deinit { close(fd) }  // 構造体にdeinitが持てる！
    
    consuming func close() {
        close(fd)
        discard self
    }
}

let file = FileHandle(path: "data.txt")
// let copy = file  // ❌ コピー不可
```

- `borrowing`: 一時的な読み取りアクセス（呼び出し側が所有権を保持）
- `consuming`: 所有権の移転（呼び出し後は使用不可）

---

## Swift 6.0 厳格な並行性チェック

**鉄則：すべての型は明示的にSendableであるか、アクターに隔離されていなければならない。**

Swift 6ではデータ競合安全性がエラーに昇格。

```swift
// Sendableの基本ルール
struct UserData: Sendable {
    let name: String  // Sendable
    let age: Int      // Sendable
}

// クラスはfinal + 全プロパティがlet + Sendable
final class Config: Sendable {
    let apiKey: String
    init(apiKey: String) { self.apiKey = apiKey }
}

// アクター隔離
actor BankAccount {
    var balance: Double = 0
    func deposit(_ amount: Double) { balance += amount }
}

// @MainActor — メインスレッドへの隔離
@MainActor
class ViewModel: ObservableObject {
    @Published var title: String = ""
}
```

Swift 6.2では「Approachable Concurrency」としてデフォルト`@MainActor`が導入され、並行性安全性がさらに実用的になっている。

---

## Opaque Types（some）vs Existential Types（any）

**鉄則：デフォルトは`some`を使え。`any`は異種コレクションが本当に必要な場合のみ。**

| 特性 | `some Protocol` | `any Protocol` |
|------|----------------|----------------|
| 基底型 | コンパイラが認識、固定 | 動的、実行時に変化可能 |
| ディスパッチ | 静的（高速） | 動的（ボクシングのオーバーヘッド） |
| 異種コレクション | ❌ | ✅ |

```swift
// some — 常に1つの具象型を返す（静的ディスパッチ）
func makeCircle() -> some Shape { Circle(radius: 5) }

// any — 異なる型を返せる（動的ディスパッチ）
func makeShape(round: Bool) -> any Shape {
    if round { Circle(radius: 5) } else { Square(side: 4) }
}
```

型理論的には、`some`はHaskellの全称量化型、`any`は存在量化型に対応する。

### Typed Throws（SE-0413）— Swift 6.0

```swift
enum ValidationError: Error {
    case emptyName
    case nameTooShort(Int)
}

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

**制約**: `throws(A, B, C)`のような共用体型は未サポート。モジュール内の固定されたエラードメインに限定して使用すべき。`throws(Never)`は非throwingと同等。
