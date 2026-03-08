# 鉄則10: pointfreeエコシステム

## pointfree.coの哲学

Brandon Williams（数学バックグラウンド）とStephen Celis（独学プログラマー）が2018年から運営。300以上のエピソードを通じてHaskellの概念をSwiftに翻訳してきた。

### 核心的な原則

1. **「関数とその合成がすべて」** — 関数型プログラミングは関数の合成に執着する
2. **副作用を境界に押し出せ** — テスト可能な純粋なコアを残す
3. **代数的データ型で不可能な状態を排除せよ** — struct = 直積、enum = 直和
4. **値型を参照型より優先せよ** — 「action at a distance」を排除

---

## Haskell概念 → Swiftライブラリ対応表

| Haskellの概念 | pointfreeのSwift実装 |
|--------------|---------------------|
| Type classes | Protocol Witness（struct + closures） |
| Reader monad | swift-dependencies（@Dependency + Task Locals） |
| Elm Architecture | TCA（Reducer + Effect + Store） |
| Contravariance / contramap | pullback |
| Prism（Optics） | swift-case-paths（@CasePathable） |
| Lens（Optics） | WritableKeyPath + `.~` / `%~` 演算子 |
| Functor map | 各型の.map（統一的抽象化は未実現） |
| Monad bind (>>=) | .flatMap |
| Kleisli composition (>=>) | >=> 演算子（手動定義） |
| IO monad | Effect<Action> |
| newtype | swift-tagged（Tagged<Tag, RawValue>） |
| Function composition (.) | <<< 演算子、swift-overture |
| Function application ($) | \|> 演算子 |
| QuickCheck | swift-gen |
| Data.Map (ordered) | swift-identified-collections |

---

## 主要ライブラリ一覧

### アーキテクチャ

| ライブラリ | 用途 | Stars |
|-----------|------|-------|
| swift-composable-architecture | Elmアーキテクチャ | 14,400+ |
| swift-navigation | 型安全ナビゲーション | — |

### 依存注入

| ライブラリ | 用途 |
|-----------|------|
| swift-dependencies | ReaderモナドDI |

### 型安全性

| ライブラリ | 用途 |
|-----------|------|
| swift-tagged | Phantom Types / Newtype |
| swift-case-paths | enumケース用KeyPath（Prism） |
| swift-identified-collections | 識別済み順序付きコレクション |

### 関数合成

| ライブラリ | 用途 |
|-----------|------|
| swift-overture | pipe, with, curry, flip 等 |
| swift-prelude | 関数型プリミティブ、演算子 |

### テスト

| ライブラリ | 用途 |
|-----------|------|
| swift-snapshot-testing | スナップショットテスト |
| swift-custom-dump | デバッグ/差分表示 |

### 互換性

| ライブラリ | 用途 |
|-----------|------|
| swift-perception | Observation の iOS 16バックポート |
| swift-clocks | Clock プロトコルのテスト用実装 |

---

## Swift Evolutionの型システム進化状況

### 実装済み（活用すべき）

- **Parameter Packs**（SE-0393）— 可変長ジェネリクス
- **Typed Throws**（SE-0413）— 精密なエフェクト追跡
- **Noncopyable Types**（SE-0390/0427/0429/0432）— 線形型
- **if/switch expressions**（SE-0380）— パターンマッチ式
- **Macros**（SE-0382/0389/0397）— コンパイル時コード生成
- **Strict Concurrency**（Swift 6.0）— データ競合安全性
- **Primary Associated Types**（SE-0346）— `any Collection<String>`

### 未実装（Haskellとのギャップ）

- **Higher-Kinded Types** — 正式なSE提案なし（2026年時点）
- **GADTs** — Generalized Algebraic Data Types
- **Type Families** — 型レベル関数
- **種システム（Kind system）** — `* -> *`レベルの型変数
- **型レベル計算** — DataKinds相当

---

## 学習リソース

### 必修エピソード（pointfree.co）

関数型の基礎を理解するために特に重要なエピソード群：

- **Ep.1-4: Functions** — 関数、副作用、高階関数の基礎
- **Ep.11: Composition without Operators** — 演算子なしの合成
- **Ep.14-17: Contravariance** — pullback、contramap
- **Ep.51-55: Composable Architecture** — TCAの原型
- **Ep.87-95: Case Paths** — enumケース用Optics
- **Ep.100+: Reducer Protocol** — 現在のTCA API

### 外部リソース

- **objc.io: Functional Swift** — Swiftにおける関数型の入門書
- **Rob Napier: Cocoaphony blog** — Never型、型システムの深い解説
- **Swift by Sundell: Phantom Types** — 実践的Phantom Types解説
