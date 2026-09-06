---
name: functional-style
description: >
  TypeScript、JavaScript、Swift、Haskell、Rustのコードを作成・レビュー・リファクタする時、
  またはユーザーが関数型を指定した時に使う。不変データ、pure core、式と型による制御を徹底する。
---

# Functional Style

新規・変更コードは、命令の列ではなく不変な値の依存グラフとして設計する。

## 優先順位

1. ユーザーの要件とrepo固有規約
2. このskillの不変性・式・型の規約
3. 既存コードとの整合
4. 言語・フレームワークの慣用

## 指針

- 再代入と可変データを避け、言語に合う不変bindingを使う。JS/TSは`let` / `var`でなく`const`、Swift/Rustはimmutableな`let`、Haskellは不変の値を使い、参照先の破壊的変更もcoreへ持ち込まない。
- 命令的な分岐文・loopを避け、値を返す式、網羅的pattern matching、map/filter/fold、再帰で表す。Rust/Swift等の値を返す`if` / `switch`式を、JS/TSの文と同じ理由で禁止しない。
- `try-catch` / `throw` で通常の失敗を扱わず、Result/Either/Option等の型で表す。
- `async/await` の逐次列を避け、Promise/Effect等の合成と明示的な並列性で表す。
- `void` を通常の戻り値にせず、副作用境界も成功・失敗を表す値を返す。
- JS/TSでは `function` keywordを使わずarrow functionを使い、`null`返却ではなくOption/Resultで表す。
- pure coreへ変換を集め、副作用は型を持つ最外周の薄い境界へ隔離する。
- 関数合成と小さなtotal functionを優先し、状態遷移は判別可能unionやreducerとして網羅的に扱う。
- 新しい抽象化・依存関係は、不変条件を型で表すために必要な最小限へ絞る。
- 同じcontractやsource of truthを複数定義せず、概念数と境界数を最小化する。
- 意味や不変条件が異なる概念には異なる名前と型を与え、曖昧な共通名へ寄せない。
- host固有path、ローカルfile I/O、process状態をcore contractにせず、stdioや引数で抽象境界へ渡す。

## 副作用境界

UI callback、FFI、framework lifecycle等で手続き的APIが避けられない場合も、その境界を薄くし、値を返すpure functionへ直ちに委譲する。既存の手続き的コードを理由に、新規・変更部分へ再代入や非網羅な制御を増やさない。

## 検証

変更した振る舞いに近いテストを先に実行し、必要な範囲だけ型検査・lint・統合テストを追加する。
