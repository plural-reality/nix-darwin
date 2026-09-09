---
name: prompt-review
description: "AIエージェント対話の利用状況を、既定では本文を出さないメタデータから点検する。browser/computer useをCLI/MCPへ見直す履歴監査にも使う。対話本文の分析は明示承認時だけ行う。"
allowed-tools: Read, Write, Glob, Grep, Bash
---

# prompt-review

対話履歴は高密度な個人・業務データである。収集対象と出力内容を分ける。既定は**メタデータのみ**で、本文・抜粋・マスク済みの値を標準出力にもレポートにも出さない。

## Codexのtool使用監査（画面操作の見直し）

「直近1か月のcomputer/browser useをCLI/MCPで置換」「操作経路を自己改善」の依頼では、この分岐だけを実行する。下の汎用`collect.py`で他のAIツールやプロンプト本文まで収集しない。

1. 読むhost・Codex保存領域・時刻窓を明示する。1か月はユーザーのタイムゾーンで起点を決め、`--since`（含む）と`--until`（含まない）を固定する。現在の監査sessionを除外する。別hostの`~/.codex`を横断読出ししない。取得できたローカル履歴と、取得できないhost/期間を分ける。
2. 同梱の[scripts/tool_usage.py](scripts/tool_usage.py)の`--help`を読み、timezone付きISO時刻を渡す。既定は当該hostの`sessions`と`archived_sessions`のみ。`--root`でfixtureや許可済みの明示領域を指定できる。出力は現在の作業領域へ保存する。
3. 出力はtool名・固定された操作種別・時刻・session ID・行番号とcoverageのみ。引数、実コード、URL、title、本文、OCR、tool結果を出力しない。`functions.exec`/`node_repl`内の参照やshell中のUI語は候補であり、実行回数・失敗回数には加算しない。fork/archivedの重複はcall IDで除き、欠測・未知形式・parse errorを明示する。
4. 件数から順位をつけ、代表例に絞って元のtool callを確認する。本文/引数の追加取得は依頼で許可された対象・用途の最小範囲に限る。未許可の会話本文・私信・機微入力が必要になったときは、下の本文分析の境界を使う。集計だけから「無駄」「置換済み」「冪等」を断定しない。
5. [browser-automationの判断表](../browser-automation/references/semantic-routing.md)で`replace`/`hybrid`/`keep_ui`/`unverified`を判定する。既存CLI/MCPが今使えるかと、当時使えたかを混同しない。
6. `self-learn`の「2-E. 画面操作から学ぶ」へ渡して正本の最小改善と検証を行う。レポートは目的・対象期間・母数・代表例のsource ID/行・判断・検証・未確認を残す。生の対話はレポートに複製しない。

## 既定: メタデータ点検

実行前に対象範囲（全ツール、プロジェクト絞込み、日数）を示し、次を実行する。

```sh
python3 "$HOME/.claude/skills/prompt-review/scripts/collect.py" --days 7
```

引数は次だけを受ける。

- `--days N`: 過去 N 日。`0` は全期間。
- `--project NAME`: プロジェクト名の部分一致。

既定出力には、ツールごとの検出状態・件数・期間、プロジェクト別件数、検出した機微情報の**種別と件数だけ**が含まれる。ここから利用頻度、対象の偏り、ログ保持範囲、機微情報の取り扱い改善を評価できる。本文の質・技術理解度・引用に関する結論は、メタデータだけから推測しない。

既定ではファイルを作らない。必要ならユーザーが指定した現在の作業領域へ、本文を含まない要約だけを書き出す。

## 本文を含む分析: 明示承認が必要

プロンプト本文をモデルへ渡す、引用する、または本文を含むレポートへ保存する前に、次を一度に明示する。

1. 読むツール・プロジェクト・期間
2. 生本文が標準出力へ現れ、分析コンテキストに入ること
3. 保存先がある場合は保存先と、本文・短い引用のどちらを保存するか

その後のユーザー発言で、変更のない範囲への明示承認を得たときだけ `--include-content` を追加する。

```sh
python3 "$HOME/.claude/skills/prompt-review/scripts/collect.py" \
  --project example --days 30 --include-content
```

本文分析では、必要最小限の短い引用に留め、資格情報・個人情報・内部URL・ファイルパスを含む箇所は引用しない。機微情報の検出結果は値・抜粋を出さず、種別・件数と、必要ならローテーション等の安全な次の操作だけを示す。

## 安全なレポート構成

`references/report-template.md` はメタデータ点検用の標準構成である。本文承認がない限り、技術理解度、依存度、成長軌跡について個人の能力を推測する評価レポートを生成しない。

## 実装境界

- collector はローカルの各ツール履歴を読むが、既定出力では message の本文を射影しない。
- `--include-content` は出力射影だけを切り替える。収集範囲・保存先・外部送信の承認を広げない。
- collector の依存は Nix 提供の Python 標準ライブラリだけである。runtime で package をインストールしない。
