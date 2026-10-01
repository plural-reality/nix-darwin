# 発信サービスの実行手順

## 既存接続

2026-10-01にElevenLabs Conversational AIと既存Twilio番号を使う発信を実測した。これは現在の接続・残高の保証ではない。発信前にAPIの現行仕様と本人の既存接続を確認する。

- API base: `https://api.elevenlabs.io/v1/convai`
- 認証: `xi-api-key` header。既存の許可された秘密管理経路からプロセス内で読む。キー値をCLI引数・出力にしない。
- `GET /phone-numbers`: 発信者番号・outbound対応・現在の着信用エージェント割当を確認。
- `POST /agents/create`: 今回の用件に専用のエージェントを用意。既存の業務用着信エージェントを変更しない。
- `GET /agents/{agent_id}`: 設定を読戻し。
- `POST /twilio/outbound-call`: 承認済み用件を1回だけ発信。
- `GET /conversations/{conversation_id}`: 通話状態と結果を読戻し。

公式仕様: [outbound call](https://elevenlabs.io/docs/api-reference/twilio/outbound-call)、[create agent](https://elevenlabs.io/docs/api-reference/agents/create)、[conversation details](https://elevenlabs.io/docs/api-reference/conversations/get)。実行時に現行schemaを確認し、不明なfieldを推測して送らない。

## 実測済み試作の位置づけ

このSkillを作成したチャット `01a0f658-94b0-7e51-81e5-5a46e734eddb` の成果物に、夕食ヒアリング専用の `dinner_call.py` と12件の安全確認テストがある。本人宛て番号・夕食の指示・状態を固定した一度限りの試作であり、汎用発信CLIではない。古い承認hashや消費済み状態を再使用せず、別用件のために固定番号だけ置換して実行しない。

このSkill自体には常駐サービスや汎用CLIは含まれない。ホスト固有のパス・電話番号・API keyを共有Skillへ埋め込まない。既存の連携が見つからなければ接続先だけを本人へ確認する。個別用件の実行コードを作る場合は以下の境界を満たしてから使用する。

## 用件ごとの固定計画

呼出しごとに新規のprivate state directory（0700、ファイル0600）を使い、計画に以下を保存する。

- 宛先の相手・E.164番号・出典、発信者番号とprovider ID
- 本人の依頼、共有可能な事実、通話指示全文と冒頭発言、委任範囲
- エージェントID、設定の読戻しsnapshotとSHA-256
- 最大時間・回数、発信可能期限・時間帯、費用条件、録音・保存設定
- 現在の着信割当、作成日時、計画全体のSHA-256

承認発言と計画hashを対応づける。hashを生成しただけでは本人の承認にはならない。エージェントへの用件送信も第三者サービスへの情報開示なので、許可された事実に限定する。

実測設定は日本語、会話180秒、無音25秒、concurrency 1、daily_limit 1、auth有効、音声録音なし、文字起こし保持最大7日、ツールはend_callだけ。現在のschemaで読戻し検証する。音声モデルや料金は固定の正解として扱わない。知識ベース・MCP・外部ツールを勝手に接続しない。既存設定の余分なtoolsや能動的workflowも検査する。

## 一度だけ発信する境界

1. 計画hash・明示承認・期限・発信条件を照合する。
2. リモート設定をGETし、承認時snapshotと一致することを検証する。発信番号と着信割当も再確認。
3. POSTより先に、排他的作成（O_EXCL）とfsyncで発信試行markerを永続化する。同じ計画の2回目は拒否。
4. 承認済みIDと宛先のみを送る。録音を無効にし、ringing timeoutも固定する。
5. receiptを永続化。timeout・接続切断・5xx・不明な応答でもmarkerは消さない。新しいdirectoryで同じ用件をやり直すことも重複防止の迂回になる。まずprovider履歴で送信有無を照合し、不明なら未確認として止める。
6. 結果をGETし、agent_idとCallSid等を照合。完了状態と発言を確認して報告する。

エージェント作成にも同じ「POST前marker・不明時は照合してから復旧」を適用し、自動再試行で作成物を増やさない。外部通信はtimeoutを設定し、エラーレスポンス全文や認証headerを表示しない。

## 変更時の最小検証

実発信なしの偽clientで、承認欠落、宛先・指示・期限の変更、リモート設定変更、予期しないtool、2回目の発信、POST応答喪失後の再実行、別通話の結果を拒否することを確認する。正常系は承認済み計画が1回だけPOSTされることを確認する。検証目的の電話にも個別の発信許可が必要。
