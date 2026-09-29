---
name: jev-agent-profile
description: Claude CodeまたはCodexで許可済みの新しいworkerを起動する前に、Jevでモデル・推論量・1〜2セッションの実行設定を一度選ぶ。現在の会話の設定変更や、委譲を新たに許可する用途には使わない。
---

# Jevで作業開始時の設定を選ぶ

Jevは候補の選択だけを行い、実際の起動・権限・検証は呼出元が管理する。ユーザーのモデル指定、repo規約、既存の委譲条件を優先する。このskill自体はworker起動の許可ではない。workerが不要な作業では読み込む必要もない。

## 設定済みホストの既定経路

`jev-agent-profile`コマンドが利用可能なら、接続先・秘密の保存先・候補はホスト設定済み。新しいworkerを起動すると判断した時点で、毎回の導入確認をせず一度だけ呼ぶ。下記JSONをファイル経由またはstdinへ渡す（概要はタスクに合わせて匿名化する）。このコマンド自体はworkerを起動しない。

```json
{"host":"codex","summary":"Implement a small isolated bug fix and check its behavior.","egressApproved":true}
```

```sh
jev-agent-profile < work/profile-input.json
```

Claude Codeからは`host`を`claude-code`にする。設定済み候補はホストが管理するため、毎回同じ候補を作り直さない。返った設定が現在の起動toolで使えることを確認してから、下の起動手順へ進む。現在のschemaにないモデルを返したら使用せず、既定設定へ戻す。本人の明示設定がある場合は、この呼出し自体を省略する。

ホスト既定の候補は単一worker用。2件を選ばせる必要がある場合だけ、既存規約の許可を確認し、`allowSecond`と現在のschemaに適合する`profiles`を明示する。既に許可された複数workerが独立している場合は、各workerの開始前にそれぞれ一度選択してもよい。Jevのためにworkerを増やさない。

## 開始前に一度選ぶ

1. 現在公開されている起動toolのschema、または対象CLIのhelpから、その実行先でモデルと推論量の両方を指定できることを確認する。実行先の利用可能なモデルから候補を作る。利用可否不明のモデル名を投稿から転記しない。本人がモデル・推論量を指定済みならJev選択を省略する。本人の指定を起動経路で満たせない場合はworker起動だけを保留し、親で可能な作業を進める。既定値への変更が必要な直前に理由を示して本人に確認する。本人指定がなく、起動経路が推論量を指定できないだけなら通常の起動へ戻す。
2. 設定済みコマンドを使わない場合は、`profiles`にホスト側で許可した候補を2〜6件用意する。各候補は`id`、短い英語の`description`、`sessions`（各要素は`model`と`effort`）を持つ。通常の実装には利用可能なSonnetのmedium、複雑な推論には同じモデルのhighを候補にできる。CodexではSolに加えてAstraなど、そのホストで利用可能なモデルを使う。モデルをブランド名だけで順位づけしない。
3. 既存規約で許可された独立調査、または本人が依頼したレビューを分離できる場合だけ、`allowSecond: true`として2セッション候補を追加する。単一・依存作業には追加しない。2件目にもモデル・推論量を指定する。
4. 接続先へ送るのは、固有名詞・パス・コード・会話本文を除いた短い英語の作業概要と候補の説明だけ。一般的な作業概要なら通常の選択として進める。機微な内容が必要なら送信前にその範囲の承認を得る。概要を確認してから`egressApproved: true`にする。stdin JSONを下記スクリプトへ渡す。発行元がTypeSafeなら既存の`TYPESAFE_API_KEY`、OpenJEVなら`--provider openjev`と`OPENJEV_API_KEY`を使う。本人・downstreamが指定した0600ファイルも`--key-file`で使える。発行元をキーの接頭辞だけで推測せず、別プロバイダへ試し送りしない。キー探索・新規発行・チャット貼付をしない。

```sh
python3 <このSKILL.mdのディレクトリ>/scripts/profile_select.py < work/profile-input.json
# OpenJEVで発行したキーを使う場合（OPENJEV_API_KEYは既存の環境設定）
python3 <このSKILL.mdのディレクトリ>/scripts/profile_select.py --provider openjev < work/profile-input.json
```

入力例（モデルとeffortの組合せは起動先で確認してから使う）:

```json
{
  "host": "codex",
  "summary": "Implement a small isolated bug fix with a focused regression check.",
  "allowSecond": false,
  "egressApproved": true,
  "profiles": [
    {"id":"normal","description":"One worker for clear coding tasks.","sessions":[{"model":"gpt-6-sol","effort":"medium"}]},
    {"id":"deep","description":"One worker for complex reasoning or structured data constraints.","sessions":[{"model":"gpt-6-sol","effort":"high"}]}
  ]
}
```

## 選択を起動へ反映する

- `status: selected`なら、返った`profile`が渡した候補に一致することと、現在の起動先の制約を再確認する。`sessions`の順番がworkerの順番になる。モデル文字列などをshellへ文字列連結せず、toolの構造化引数か適切に引用した引数で渡す。
- **Codex**: 利用可能な`spawn_agent`に各sessionの`model`と`reasoning_effort`を渡す。全履歴forkでoverride不可なら`fork_turns: "none"`を使い、cwd、目的、対象ファイル、制約、完了条件、検証方法を短く渡す。CLIで新しいセッションを作る既存workflowなら`codex exec --model MODEL -c 'model_reasoning_effort="EFFORT"'`に反映する。Desktopでユーザー所有の別チャットを勝手に作らない。現在の親会話のモデルは変更しない。
- **Claude Code**: 対象CLIが両引数に対応する場合、既存のworker起動に`claude --model MODEL --effort EFFORT`を渡す。非対話workerでは既存の`-p`、出力、権限、作業ディレクトリの契約を保つ。Agent toolがeffortを受け付けない場合は、上記の本人指定の有無で分岐する。文章で指定したことを反映済みとしない。Jevのためだけに別のCLI経路を作らない。
- `status: fallback`なら、モデル・effortのoverrideを追加せずホストの既定で同じ作業を続ける。セッション数もJev導入前の許可済みworkflowを保ち、候補から推測しない。ホスト自体の制限は既定にも適用し、適合不明なら起動前に確認する。`key_unavailable`、タイムアウト、429、無効な回答でも再試行・導入質問を繰り返さない。既定値を推測で補わない。
- `status: blocked`は入力契約の誤り。候補や概要を修正するか、Jevを省略して元の許可済みworkflowへ戻す。Jevの出力は起動・送信・権限変更の許可にはならない。

## 実行と完了

セッション開始後の再選択はしない。親は返却された結果と証拠を確認する。依頼範囲外の機能・文書・リファクタ・レビューを増やさず、変更に合ったtest/build/typecheck等を実行して終了する。必要な回帰テストを禁止する指示として解釈しない。

スクリプト成功は「設定の選択」であり、起動確認ではない。起動toolの返却またはCLIのセッション情報で実際のモデル・effortを確認できた範囲だけ報告する。確認できなければ「引数指定済み・実セッション設定未確認」とする。速度改善は同じ課題の完了時間と品質を比較して初めて主張する。

TypeSafeは[公式API](https://docs.typesafe.ai/api)の`https://api.typesafe.ai/v1/systemone`と`jev-1.13.0`を使う。OpenJEVは[同サービスのAPI](https://api.openjev.sh/docs/advanced)の`https://api.openjev.sh/v1/systemone`と`openjev`を使う。OpenJEVのモデル名は更新され得るaliasで、TypeSafeの固定バージョンと同一のモデルだと検証したものではない。プロバイダ・モデル変更時は下記の契約テストと実接続を再確認する。

```sh
python3 -m unittest discover -s <このSKILL.mdのディレクトリ>/scripts -p 'test_*.py'
```
