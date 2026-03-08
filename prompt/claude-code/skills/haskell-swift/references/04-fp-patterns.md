# 鉄則4: 関数型プログラミングパターン

## カリー化と部分適用

Haskellではすべての関数が自動カリー化。Swiftでは手動定義が必要（SE-0002で構文削除済み）。

```swift
// 汎用curry関数
func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    { a in { b in f(a, b) } }
}

func curry<A, B, C, D>(_ f: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
    { a in { b in { c in f(a, b, c) } } }
}

// 使用例
func add(_ x: Int, _ y: Int) -> Int { x + y }
let curriedAdd = curry(add)
let addTwo = curriedAdd(2)       // (Int) -> Int
[1, 2, 3].map(curriedAdd(10))   // [11, 12, 13]

// 直接カリー化スタイル
func createURL(_ baseURL: String) -> (String) -> String {
    { path in "\(baseURL)/\(path)" }
}
let siteURL = createURL("https://mysite.com")
siteURL("login")      // "https://mysite.com/login"
```

---

## 関数合成演算子

**鉄則：小さな純粋関数を定義し、合成演算子で組み立てよ。**

```swift
// パイプフォワード演算子 |>（Haskellの $ に相当、方向は逆）
precedencegroup ForwardApplication {
    associativity: left
    higherThan: AssignmentPrecedence
}
infix operator |>: ForwardApplication
func |> <A, B>(a: A, f: (A) -> B) -> B { f(a) }

// 前方合成演算子 >>>（Haskellの >>> に相当）
precedencegroup ForwardComposition {
    associativity: left
    higherThan: ForwardApplication
}
infix operator >>>: ForwardComposition
func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { a in g(f(a)) }
}

// 後方合成演算子 <<<（Haskellの . に相当）
infix operator <<<: ForwardComposition
func <<< <A, B, C>(
    _ g: @escaping (B) -> C,
    _ f: @escaping (A) -> B
) -> (A) -> C {
    { a in g(f(a)) }
}

// 使用例
func incr(_ x: Int) -> Int { x + 1 }
func square(_ x: Int) -> Int { x * x }

2 |> incr |> square |> String.init  // "9"
let transform = incr >>> square >>> String.init
[1, 2, 3].map(incr >>> square)      // [4, 9, 16]
```

### swift-overture — 名前付き関数版

演算子を好まない場合のライブラリ。

```swift
import Overture
let result = pipe(incr, square, String.init)
[1, 2, 3].map(pipe(incr, square))  // [4, 9, 16]

// with — 即時適用
with(42, pipe(incr, square, String.init))  // "1849"
```

---

## Optics — LensとPrism

**Lens**は直積型（struct）のプロパティにフォーカス、**Prism**は直和型（enum）のケースにフォーカス。

```swift
struct Lens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
    
    func modify(_ transform: @escaping (Part) -> Part) -> (Whole) -> Whole {
        { whole in self.set(transform(self.get(whole)), whole) }
    }
    
    // Lens合成
    func composed<NewPart>(_ other: Lens<Part, NewPart>) -> Lens<Whole, NewPart> {
        Lens<Whole, NewPart>(
            get: { other.get(self.get($0)) },
            set: { newPart, whole in
                self.set(other.set(newPart, self.get(whole)), whole)
            }
        )
    }
}
```

### WritableKeyPath — Swiftの組み込みLens

SwiftのWritableKeyPathは組み込みのLens。swift-preludeは`.~`（set）と`%~`（over/modify）演算子を提供。

### swift-case-paths — enumケース用KeyPath

`@CasePathable`マクロによりPrismが自動生成される。

```swift
import CasePaths

@CasePathable
enum Action {
    case increment
    case setText(String)
}
// \Action.Cases.setText は CasePath<Action, String>
```

TCAのScope、navigationで多用される。

---

## Railway Oriented Programming

**鉄則：失敗する可能性のある処理はResultのflatMapチェインで合成せよ。**

```swift
enum UserError: Error {
    case invalidEmail, invalidPassword, duplicateEmail
}

func validateEmail(_ input: String) -> Result<String, UserError> {
    input.contains("@") ? .success(input) : .failure(.invalidEmail)
}

func validatePassword(_ input: String) -> Result<String, UserError> {
    input.count >= 8 ? .success(input) : .failure(.invalidPassword)
}

// Kleisli合成演算子（Haskellの >=> に相当）
infix operator >=>: ForwardComposition
func >=> <A, B, C, E: Error>(
    _ f: @escaping (A) -> Result<B, E>,
    _ g: @escaping (B) -> Result<C, E>
) -> (A) -> Result<C, E> {
    { a in f(a).flatMap(g) }
}

let pipeline = validateEmail >=> validatePassword
let result = pipeline("test@example.com")
```

---

## Writer/Reader/Stateモナドの実用的代替

| Haskellモナド | Swift実装 |
|--------------|----------|
| Writer w a | タプル`(A, [Log])`と合成、またはログフレームワーク |
| Reader r a | `@Dependency`、`@Environment`（プロパティラッパーDI） |
| State s a | `inout`パラメータ＋値型変異、TCA Reducer |

```swift
// Readerモナド（理論的実装）
struct Reader<E, A> {
    let run: (E) -> A
    
    func map<B>(_ f: @escaping (A) -> B) -> Reader<E, B> {
        Reader<E, B> { e in f(self.run(e)) }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Reader<E, B>) -> Reader<E, B> {
        Reader<E, B> { e in f(self.run(e)).run(e) }
    }
}

// 実用的には @Dependency（swift-dependencies）がReader実装
@Dependency(\.apiClient) var apiClient
```
