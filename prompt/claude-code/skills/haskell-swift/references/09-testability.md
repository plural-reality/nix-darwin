# 鉄則9: テスト容易性と純粋性

## Protocol Witnessパターン

**鉄則：依存性にはプロトコルではなく、struct + closuresのProtocol Witnessパターンを使え。**

pointfree.coが教えるこのパターンは、Gabriella Gonzalezの「Scrap Your Type Classes」に直接インスパイアされている。

```swift
// ❌ 従来のプロトコルベース
protocol APIClientProtocol {
    func fetchUser(id: Int) async throws -> User
}

// ✅ Protocol Witness（struct + closures）
struct APIClient {
    var fetchUser: @Sendable (Int) async throws -> User
}

// 利点：複数の「適合」が可能
let liveClient = APIClient(fetchUser: { id in /* 実ネットワーク */ })
let testClient = APIClient(fetchUser: { _ in User(name: "Test") })
let failingClient = APIClient(fetchUser: { _ in throw APIError.offline })
```

### プロトコルに対する優位性

| 側面 | Protocol | Protocol Witness |
|------|----------|-----------------|
| 適合数 | 型あたり1つのみ | 無制限 |
| Associated Type問題 | あり（PATの制約） | なし |
| 型消去 | `AnyPublisher`等が必要 | 不要 |
| テストモック | MockAPIClient classが必要 | クロージャ差し替えだけ |
| 合成 | 困難 | pullback（contramap）で自然 |

---

## swift-dependenciesライブラリ

### 依存の定義と登録

```swift
// 1. Protocol Witnessで依存を定義
struct APIClient {
    var fetchUser: @Sendable (Int) async throws -> User
    var updateUser: @Sendable (User) async throws -> Void
}

// 2. DependencyKeyでlive/test/previewを登録
extension APIClient: DependencyKey {
    static let liveValue = APIClient(
        fetchUser: { id in try await realFetch(id) },
        updateUser: { user in try await realUpdate(user) }
    )
    static let testValue = APIClient(
        fetchUser: { _ in .mock },
        updateUser: { _ in }
    )
    static let previewValue = APIClient(
        fetchUser: { _ in .preview },
        updateUser: { _ in }
    )
}

// 3. DependencyValuesに登録
extension DependencyValues {
    var apiClient: APIClient {
        get { self[APIClient.self] }
        set { self[APIClient.self] = newValue }
    }
}

// 4. 使用側
@Dependency(\.apiClient) var apiClient
```

### @DependencyClientマクロ

未オーバーライドのエンドポイント呼び出しでテスト自動失敗を生成。

```swift
@DependencyClient
struct SearchClient {
    var search: @Sendable (String) async throws -> [SearchResult]
    var suggest: @Sendable (String) async throws -> [String]
}

// テストでsearchだけオーバーライドし、suggestを呼ぶとテスト失敗
```

---

## テストでの依存差し替え

```swift
@Test func testFeature() async {
    let store = TestStore(initialState: Feature.State()) {
        Feature()
    } withDependencies: {
        $0.apiClient.fetchUser = { id in
            User(id: id, name: "テストユーザー")
        }
        $0.continuousClock = ImmediateClock()
        $0.uuid = .incrementing
        $0.date = .constant(.now)
    }
    
    await store.send(.loadUser(id: 42)) {
        $0.isLoading = true
    }
    await store.receive(\.userLoaded) {
        $0.isLoading = false
        $0.user = User(id: 42, name: "テストユーザー")
    }
}
```

---

## TCA TestStoreの網羅的テスト

TestStoreは全状態変更と全受信Effectアクションの断言を要求する。何も見逃さない。

### テスト設計の鉄則

1. **全状態変更をアサートする** — `store.send(.action) { $0.field = value }`の`{ }`ブロックで期待する状態変更を明示
2. **全Effect受信をアサートする** — `store.receive(\.action)`で副作用からのアクションを捕捉
3. **依存は必ず差し替える** — `withDependencies`でテスト用の依存を注入
4. **時間を制御する** — `ImmediateClock`でデバウンス等をスキップ
5. **ランダム性を排除する** — `uuid = .incrementing`、`date = .constant(...)`

### 非網羅的テスト（必要な場合）

```swift
// exhaustivity を off にすることも可能（推奨しない）
store.exhaustivity = .off
await store.send(.someAction)
// 状態変更のアサートを省略可能
```

---

## Haskell的テスト哲学との対応

| Haskell | Swift/TCA |
|---------|-----------|
| QuickCheck（プロパティベーステスト） | swift-gen（pointfree） |
| HSpec（振る舞い駆動テスト） | TestStore（状態遷移テスト） |
| モナドインスタンスの交換 | withDependencies |
| IORef + STRef | @Dependency + TestStore |
