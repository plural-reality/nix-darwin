# 鉄則5: SwiftUI × TCAアーキテクチャ

## TCAの設計哲学

TCA（The Composable Architecture）はpointfree.coのBrandon WilliamsとStephen Celisによるフレームワークで、**ElmアーキテクチャのSwift実装**。4つの構成要素で成り立つ：

- **State**: 機能のデータを記述する値型（struct）
- **Action**: すべての可能なイベントを表すenum
- **Reducer**: Stateを純粋に変換し、Effectを返す純粋関数
- **Store**: Reducerを駆動し、Effectを実行するランタイム

## 基本パターン

```swift
import ComposableArchitecture

@Reducer
struct CounterFeature {
    @ObservableState
    struct State: Equatable {
        var count = 0
        var numberFact: String?
        var isLoading = false
    }
    
    enum Action {
        case incrementButtonTapped
        case decrementButtonTapped
        case factButtonTapped
        case factResponse(String)
    }
    
    @Dependency(\.numberFactClient) var numberFactClient
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .incrementButtonTapped:
                state.count += 1
                return .none  // 副作用なし
                
            case .decrementButtonTapped:
                state.count -= 1
                return .none
                
            case .factButtonTapped:
                state.isLoading = true
                return .run { [count = state.count] send in
                    let fact = try await numberFactClient.fetch(count)
                    await send(.factResponse(fact))
                }
                
            case let .factResponse(fact):
                state.isLoading = false
                state.numberFact = fact
                return .none
            }
        }
    }
}
```

`@Reducer`マクロが自動生成するもの：
- `Reducer`プロトコル適合
- `@CasePathable`アノテーション
- `ReducerOf<Self>`型エイリアス

`@ObservableState`は値型（struct）で動作するSwiftのObservation相当。iOS 16にもswift-perception経由でバックポートされている。

---

## Viewは状態の純粋関数

**鉄則：ViewはStoreの状態を読み取り、アクションを送信するだけの純粋なレンダラーであるべき。**

```swift
struct CounterView: View {
    let store: StoreOf<CounterFeature>
    
    var body: some View {
        Form {
            Text("\(store.count)")
            Button("Increment") { store.send(.incrementButtonTapped) }
            if store.isLoading {
                ProgressView()
            }
            if let fact = store.numberFact {
                Text(fact)
            }
        }
    }
}
```

TCA 1.7+ではViewStoreとWithViewStoreは不要。Viewは`Store`から直接状態にアクセスする。

---

## Reducer合成

TCAのReducer合成は関数合成の直接的な応用。`Scope`がキーパスで子Reducerを親ドメインに埋め込む。

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var counter = CounterFeature.State()
        var settings = SettingsFeature.State()
    }
    
    enum Action {
        case counter(CounterFeature.Action)
        case settings(SettingsFeature.Action)
    }
    
    var body: some Reducer<State, Action> {
        Scope(state: \.counter, action: \.counter) {
            CounterFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
```

---

## Effect型 — IOモナドとの対応

TCAの`Effect<Action>`は副作用の記述であり、実行ではない。ReducerはEffect値を返し、Storeランタイムがそれを実行する。HaskellのIOモナドと同じ哲学。

| Haskell IOモナド | TCA Effect |
|-----------------|------------|
| `IO a`は副作用の記述 | `Effect<Action>`は副作用の記述 |
| IO値の構築は純粋 | Reducerは純粋関数 |
| `>>=`（bind）で逐次化 | `.merge`、`.concatenate`で合成 |
| モナドインスタンスの交換 | `withDependencies`で依存を差し替え |

```swift
// Effect の主要パターン
return .none                        // 副作用なし
return .run { send in               // 非同期副作用
    let data = try await api.fetch()
    await send(.dataLoaded(data))
}
return .merge(effect1, effect2)     // 並列実行
return .run { ... }
    .cancellable(id: CancelID.search, cancelInFlight: true)
```

---

## @Dependency — ReaderモナドのSwift実装

SwiftUIの`@Environment`にインスパイアされた依存性注入システム。内部的にはSwift Task Localsで伝播。

```swift
// 1. 依存インターフェースの定義（Protocol Witnessパターン）
struct NumberFactClient {
    var fetch: @Sendable (Int) async throws -> String
}

// 2. DependencyValuesへの登録
extension NumberFactClient: DependencyKey {
    static let liveValue = NumberFactClient(
        fetch: { number in
            let (data, _) = try await URLSession.shared.data(
                from: URL(string: "http://numbersapi.com/\(number)")!
            )
            return String(decoding: data, as: UTF8.self)
        }
    )
    static let testValue = NumberFactClient(
        fetch: { _ in "テスト用ファクト" }
    )
}

extension DependencyValues {
    var numberFactClient: NumberFactClient {
        get { self[NumberFactClient.self] }
        set { self[NumberFactClient.self] = newValue }
    }
}
```

---

## @State/@Bindingとの共存戦略

| ユースケース | 推奨 |
|------------|------|
| 一時的なUI状態（フォーカス、アニメーション、ポップオーバー） | SwiftUI `@State` |
| ビジネスロジック、共有状態、テスト必要 | TCA `Store` |

```swift
struct FeatureView: View {
    @Bindable var store: StoreOf<LoginFeature>
    @State private var isShowingPopover = false  // ビューローカル

    var body: some View {
        Form {
            TextField("Username", text: $store.username)  // TCA binding
            Button("Info") { isShowingPopover = true }    // ローカル@State
            .popover(isPresented: $isShowingPopover) { Text("Info") }
        }
    }
}
```

`BindingReducer()`と`BindableAction`プロトコルにより、TCA状態への双方向バインディングがSwiftUIネイティブのバインディング構文で動作する。

---

## TestStoreによる網羅的テスト

TCAのTestStoreは全状態変更と全受信Effectアクションの断言を要求する。

```swift
@Test func testCounter() async {
    let store = TestStore(initialState: CounterFeature.State()) {
        CounterFeature()
    } withDependencies: {
        $0.numberFactClient.fetch = { _ in "42は答え" }
    }
    
    await store.send(.incrementButtonTapped) {
        $0.count = 1
    }
    
    await store.send(.factButtonTapped) {
        $0.isLoading = true
    }
    await store.receive(\.factResponse) {
        $0.isLoading = false
        $0.numberFact = "42は答え"
    }
}
```
