# 鉄則3: HKTエミュレーションと現実的な限界

## なぜHKTが必要なのか

Haskellの`Functor`型クラスは種（kind）`* -> *`の型変数`f`を抽象化する。

```haskell
class Functor f where
  fmap :: (a -> b) -> f a -> f b
```

SwiftではArrayにもOptionalにもmapがあるが、「mapを持つもの一般」をプロトコルで抽象化できない。2026年現在もネイティブHKTは未実装。

## Kind<F, A>ラッパーによるエミュレーション

Yallop & Whiteの脱関数化（defunctionalization）アプローチ。

```swift
// HKTインフラストラクチャ
class Kind<F, A> {}

// Witness型（型タグ）
final class ForMaybe {}

// 実データ型がKindを継承
final class Maybe<A>: Kind<ForMaybe, A> {
    let value: A?
    init(_ value: A?) { self.value = value }
    
    static func fix(_ fa: Kind<ForMaybe, A>) -> Maybe<A> {
        fa as! Maybe<A>  // 安全でないダウンキャスト
    }
}

// Functor型クラスをプロトコルとして表現
protocol Functor {
    static func map<A, B>(_ fa: Kind<Self, A>, _ f: @escaping (A) -> B) -> Kind<Self, B>
}

protocol Monad: Functor {
    static func pure<A>(_ a: A) -> Kind<Self, A>
    static func flatMap<A, B>(
        _ fa: Kind<Self, A>, 
        _ f: @escaping (A) -> Kind<Self, B>
    ) -> Kind<Self, B>
}

// Maybe用のFunctorインスタンス
extension ForMaybe: Functor {
    static func map<A, B>(_ fa: Kind<ForMaybe, A>, _ f: @escaping (A) -> B) -> Kind<ForMaybe, B> {
        let maybe = Maybe.fix(fa)
        return Maybe(maybe.value.map(f))
    }
}

extension ForMaybe: Monad {
    static func pure<A>(_ a: A) -> Kind<ForMaybe, A> { Maybe(a) }
    
    static func flatMap<A, B>(
        _ fa: Kind<ForMaybe, A>, 
        _ f: @escaping (A) -> Kind<ForMaybe, B>
    ) -> Kind<ForMaybe, B> {
        let maybe = Maybe.fix(fa)
        guard let value = maybe.value else { return Maybe<B>(nil) }
        return f(value)
    }
}
```

## 現実的な限界

| 側面 | Haskell | Swiftエミュレーション |
|------|---------|---------------------|
| ネイティブサポート | 型システムに組み込み | クラスベースのラッパー階層 |
| 型安全性 | 完全 | `as!`強制キャスト必要 |
| パフォーマンス | ゼロオーバーヘッド | クラスアロケーション、ボクシング |
| 人間工学 | `fmap f x` | `ForMaybe.map(kindValue, f)` — 冗長 |

## bow-swiftの現状

HKTエミュレーションを大規模に実装した包括的FPライブラリだったが、2021年頃から事実上メンテナンス停止。代替としてpointfreeエコシステムが実用的な解を提供している。

**鉄則：本番コードでのフルHKTエミュレーションは避けよ。代わりに、具体的なユースケースごとにmap/flatMapを定義し、pointfreeライブラリを活用せよ。**

## 実用的な代替アプローチ

HKTが欲しくなる場面の多くは、以下で対処できる：

- `map`/`flatMap`は各型に個別に定義する（Arrayの.map、Optionalの.flatMap、Resultの.flatMap）
- 抽象化が必要な場合はプロトコルのassociatedtypeを使う（ただしPAT制約あり）
- TCAのReducerProtocolのようにドメイン特化の合成インターフェースを設計する
