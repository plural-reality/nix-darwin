---
name: haskell-swift
description: SwiftUI iOSアプリ開発においてHaskellレベルの型安全性と関数型プログラミングを徹底するための鉄則ガイド。Swiftコードを書く際、レビューする際、設計する際に必ず参照する。Phantom Types、Tagged Types、TCA（The Composable Architecture）、Railway Oriented Programming、Protocol Witnessパターン、不変性の徹底、網羅的パターンマッチ、Typed Throws、Noncopyable Types、関数合成、Optics（Lens/Prism）、swift-dependenciesによる依存注入など、Swiftの型システムを限界まで活用するテクニックを網羅する。SwiftUIアプリの新規設計、既存コードのリファクタリング、コードレビュー、アーキテクチャ選定で必ず使う。「型安全」「関数型」「TCA」「Reducer」「副作用分離」「テスト容易性」「不変性」といったキーワードが出たら即座にトリガーすること。
---

# Haskell-Swift 鉄則ガイド

SwiftUI iOSアプリ開発において、Swiftの型システムを限界までHaskellレベルに引き上げるための鉄則集。

## 基本原則

1. **不可能な状態を型で表現不可能にせよ** — Phantom TypesとTagged型でバグのクラス全体を消滅させる
2. **副作用を境界に押し出せ** — Reducerは純粋関数、EffectはIOモナド
3. **依存を値として扱え** — Protocol Witnessと`@Dependency`でReaderモナドを実現
4. **defaultケースを書くな** — 全ケース明示で網羅性をコンパイラに強制させよ
5. **structをデフォルトにせよ** — classは共有参照が本質的に必要な場合のみ
6. **小さな純粋関数を合成せよ** — カリー化・パイプ・関数合成で組み立てる

---

## 鉄則一覧と参照先

各鉄則の詳細はreferencesディレクトリに格納されている。該当するトピックが出現したら、対応するファイルを読み込んで適用すること。

### 鉄則1: 型システムを限界まで押し上げる
→ [references/01-type-system.md](./references/01-type-system.md)

Phantom Types、Tagged/Newtype（swift-tagged）、Result型とNever型の高度な活用。型パラメータで状態遷移を表現し、同じ基底型でも意味的に異なる値を区別する。

**適用場面**: ID型の設計、バリデーション済み/未済の区別、状態マシン、単位系

### 鉄則2: Swift最新機能の活用
→ [references/02-modern-swift.md](./references/02-modern-swift.md)

Swift 5.9のマクロ、Parameter Packs、if/switch式、Noncopyable型。Swift 6.0のStrict Concurrency（Sendable、actor isolation）、Typed Throws。`some` vs `any`の使い分け。

**適用場面**: 新しいSwift機能の採用判断、並行性安全性の設計、所有権管理

### 鉄則3: HKTエミュレーションと現実的な限界
→ [references/03-hkt-emulation.md](./references/03-hkt-emulation.md)

Kind<F,A>ラッパーによるFunctor/Monad疑似実装、bow-swiftの現状、なぜ本番コードではフルHKTエミュレーションを避けるべきか。

**適用場面**: 抽象化の設計判断、ライブラリ選定

### 鉄則4: 関数型プログラミングパターン
→ [references/04-fp-patterns.md](./references/04-fp-patterns.md)

カリー化、部分適用、関数合成演算子（`|>`、`>>>`、`<<<`）、swift-overture。Optics（Lens/Prism）とswift-case-paths。Railway Oriented Programming（Result flatMapチェイン、Kleisli合成）。Writer/Reader/Stateモナドの実用的代替。

**適用場面**: データ変換パイプライン、エラーハンドリングチェイン、深いネスト構造の操作

### 鉄則5: SwiftUI × TCAアーキテクチャ
→ [references/05-tca-architecture.md](./references/05-tca-architecture.md)

TCAの設計哲学（Elm Architecture）、@Reducer/@ObservableState、Reducer合成、Effect型とIOモナドの対応、@Dependencyによる依存注入、@State/@Bindingとの共存戦略、TestStoreによる網羅的テスト。

**適用場面**: アプリアーキテクチャ設計、機能モジュールの設計、テスト戦略

### 鉄則6: 不変性の徹底
→ [references/06-immutability.md](./references/06-immutability.md)

struct vs classの判断基準、Copy-on-Write、let徹底、Sendable適合。

**適用場面**: データモデル設計、並行処理、コードレビュー

### 鉄則7: パターンマッチングと網羅性
→ [references/07-pattern-matching.md](./references/07-pattern-matching.md)

default禁止の理由、@unknown default、ネストされたパターンマッチング、guard case/if case。

**適用場面**: enum設計、switchの書き方、エラー型のハンドリング

### 鉄則8: 型安全なエラーハンドリング
→ [references/08-error-handling.md](./references/08-error-handling.md)

throws vs Result vs Optionalの判断マトリクス、Swift 6.0 Typed Throws、エラードメインモデリング。

**適用場面**: APIエラー設計、バリデーション、非同期処理のエラー伝播

### 鉄則9: テスト容易性と純粋性
→ [references/09-testability.md](./references/09-testability.md)

Protocol Witnessパターン、swift-dependencies、@DependencyClient、TCA TestStore。

**適用場面**: 依存性設計、モック戦略、テスト設計

### 鉄則10: pointfreeエコシステム
→ [references/10-ecosystem.md](./references/10-ecosystem.md)

pointfree.coの哲学、主要ライブラリ一覧と用途、Haskell概念との対応表。

**適用場面**: ライブラリ選定、学習リソース、設計判断の背景理解

---

## 使い方

コードを書く・レビューする・設計する際に、以下の順序で適用する：

1. **データモデル設計時** → 鉄則1（型システム）+ 鉄則6（不変性）+ 鉄則7（パターンマッチ）
2. **アーキテクチャ設計時** → 鉄則5（TCA）+ 鉄則9（テスト容易性）+ 鉄則10（エコシステム）
3. **ロジック実装時** → 鉄則4（FPパターン）+ 鉄則8（エラーハンドリング）
4. **新機能採用時** → 鉄則2（最新Swift）+ 鉄則3（HKT限界）
5. **コードレビュー時** → 全鉄則をチェックリストとして使用
