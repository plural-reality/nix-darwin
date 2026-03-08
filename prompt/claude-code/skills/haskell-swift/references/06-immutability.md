# 鉄則6: 不変性の徹底

## struct vs classの本質的な違い

**鉄則：デフォルトはstructを使え。classは共有参照が本質的に必要な場合のみ。**

```swift
// CLASS: let は参照のみ固定、中身は変更可能
class A { var value = 10 }
let a = A()
a.value = 20  // ✅ コンパイル成功！オブジェクトは変更可能

// STRUCT: let はすべてを固定
struct B { var value = 10 }
let b = B()
// b.value = 20  // ❌ コンパイルエラー！構造体全体が不変
```

structの`let`宣言は深い不変性を保証する。`mutating`キーワードは変異を可視的かつ意図的にする。

### classが必要な場合（限定的）

- UIKitの既存クラス階層との互換（UIViewController等）
- 参照アイデンティティが本質的に必要（例：`===`で同一性を判定）
- Objective-Cとのブリッジ
- TCAの`@Observable`クラス（フレームワーク要件）

上記以外では常にstructを使う。

---

## Copy-on-Write（CoW）

Swift標準ライブラリのArray、Dictionary、Set、Stringに適用される最適化。カスタム型には自動適用されない。

```swift
var a = [1, 2, 3]    // バッファ確保、refcount = 1
var b = a             // コピーなし！同じバッファを共有、refcount = 2
b.append(4)           // ここでコピー発生 — bが独自のバッファを取得
// a は [1, 2, 3]のまま、b は [1, 2, 3, 4]
```

内部的には`isKnownUniquelyReferenced`でチェック。参照カウントが1ならインプレース変更、2以上ならディープコピー。

---

## letバインディングの徹底

```swift
// ✅ 変更しないものはlet
let userName = fetchUserName()
let config = AppConfig(apiKey: "...")

// ❌ 不必要なvar
var userName = fetchUserName()  // この後変更しないならletにすべき
```

SwiftLintの`prefer_let`ルールを有効化し、CIで強制する。

---

## Sendable適合と不変データ

Sendableは型レベルでの不変性を並行性ドメインで強制する。

```swift
// ✅ 不変structは自動的にSendable
struct UserData: Sendable {
    let name: String
    let age: Int
}

// ✅ final class + let only
final class Config: Sendable {
    let apiKey: String
    let timeout: TimeInterval
    init(apiKey: String, timeout: TimeInterval) {
        self.apiKey = apiKey
        self.timeout = timeout
    }
}

// ❌ varを含むclassはSendableにできない
class MutableState {
    var count = 0  // データ競合の温床
}
```

不変データは本質的にSendable — Haskellの純粋関数と同じ原理。不変データは自由に共有可能。

---

## Haskellのデフォルト不変性との比較

Haskellは「すべてがデフォルトで不変」。Swiftは「値セマンティクスで同じ保証をローカルに提供し、変異が必要な場所ではinout変更を提供する」という実用的アプローチ。

TCAのReducerにおける`inout State`は、Haskellの`State`モナドに対応する — 変異はReducer内に閉じ込められ、外部からは純粋に見える。

```swift
// TCA Reducer内のinout — 制御された変異
Reduce { state, action in
    state.count += 1  // inout経由の変異だが、Reducer外からは純粋関数
    return .none
}
```
