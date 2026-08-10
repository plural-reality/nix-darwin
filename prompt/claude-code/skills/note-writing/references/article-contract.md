# 記事台帳と著者の眼差し

## 記事台帳

既存のCosense記事ページへ、必要な項目だけ足す。

```text
[** 記事の問い]
[** 自分の仮説]
[** 現場で裏切られたこと]
[** 壊してはいけない既存の強さ]
[** 出典台帳]
 [公開資料]
 [本人の観察・発言]
 [他者の発言]
 [AIによる整理]
 [未確認]
[** voice corpus]
[** 修正から得た学び]
[** 公開とreadback]
[** 共有先と反応]
[** 公開後の指標]
```

空の項目を埋めるために情報を捏造しない。

## 出典レコード

資料ごとに次を持つ。

```text
kind: public | private | interview | observation | ai-summary
source_ref: URL、ページ名、thread ID、またはnative log pointer
accessed_at: 確認日時
claim_scope: 何を支える資料か
verification_status: verified | partial | unverified
publication_constraint: public | attribution-required | permission-required | private
```

録音、私信、分析CSV、画像原本、preview keyは台帳へ複製しない。正本へのpointerだけを置く。

## リーチアウト記録

連絡本文や連絡先を複製せず、eventとして残す。

```text
article_key: note_keyまたは記事ページ
person_page: Cosense人物ページ
purpose: thanks | fact-check | share | feedback | collaboration
state: drafted | sent | verified | replied
at: 日時
evidence_ref: native thread pointer
```

`sent`と`verified`を分ける。

## 著者の眼差しの初期候補

これは完成した人格定義ではなく、複数記事と修正履歴で検証する候補である。

### 現場が仮説を裏切る瞬間

結論を先に持ち込まず、訪問前の仮説と、現場で認識が変わった理由を書く。

反転がなければ作らない。

### 完成品より変換過程を見る

何が完成したかより、発言、紙、データ、提言、判断、執行が何へ変わったかを見る。

### 既存の強さを置換しない

紙、対面、身体性、人が担う継承を「古い」と断じない。

技術は、それらを壊さず後段の追跡や翻訳を助ける位置へ置く。

### AIを決定者にしない

AIは地図、翻訳、監査、問い返しの補助線として扱う。

誰が決めるか、誰が責任を引き受けるかを隠さない。

### 抽象と手触りを往復する

現地の具体物から制度やアーキテクチャへ上がり、最後は小さく可逆な実験へ戻る。

### 未収束を隠さない

自分の誤算、失敗、未実装、STT未校正、確認できていないことを記事価値から排除しない。

### 人の営みへの敬意を壊さない

遅く見える制度にも、時間をかけて育った知恵がある前提で観察する。

## voice corpus候補

本文をskillへ複製せず、公開記事と本人編集箇所を参照する。

- 多治見市民討議会視察レポート：現場、変換過程、表象と統治、最小実験
  - https://note.com/tkgshn/n/ncdfb4ca25fa7
- NORTH KYOTO 66km完走レポート：身体感覚、準備ミス、数値、成功譚にしない語り
  - https://note.com/tkgshn/n/n8f5151b28d0f
- How Buildings Learn：具体例から維持能力へ上がり、類似と限界を分ける
  - https://note.com/tkgshn/n/naba3aaebd80c
- AI SlopとAsk Question：実践から原理へ上がり、未収束を残す
  - https://note.com/tkgshn/n/n6017bebbd59d
- Civic AI：一次資料、STT、注釈、未校正全文の出典境界
  - https://note.com/tkgshn/n/n612a41b4313e

記事全体を本人の手書きとみなさない。執筆threadや編集差分で本人が書いた範囲を確認する。

## red flags

- 報告書調へ均す
- 抽象語だけで進める
- AIの全知視点で語る
- 技術や製品を最初に出す
- 現場を成功譚へ加工する
- 本人の迷いや認識変更を消す
- 他者の発言と本人の解釈を混ぜる
- 一記事の癖を恒久的な人格へ昇格する
