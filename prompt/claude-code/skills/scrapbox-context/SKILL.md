---
name: scrapbox-context
description: Scrapbox/Cosense の plural-reality・tkgshn-private・takalog を横断検索し、必要なページだけを cosense-fetch で取得して回答する。
---

# Scrapbox Context スキル — ナレッジベースから情報を取得して回答する

ユーザーの質問に対して、Scrapbox（Cosense）のナレッジベースから関連情報を取得し、1-hop/2-hop のリンクネットワークを活用して回答を補強する。

## 関連スキル

| スキル | いつ使うか |
|---|---|
| `save-to-scrapbox` | 取得した情報を踏まえて Scrapbox に書き込むとき（**canonical な書き方規約**） |
| `natural-writing` | 書く前に文体ガイドライン（AI文体パターン回避）を確認 |
| `scrapbox-llm-marking` | LLM 装飾の仕組み（`[( …]` 薄表示）の背景 |

このスキルは **読み専用**。書く必要があるときは `save-to-scrapbox` を起点に。

## トリガー

### 自動トリガー（ユーザーの指示なしで使う）

以下の場合、このスキルを**自動的に**使用すること:

1. **ユーザーが個人的な知識について質問したとき**: 「〜について何か書いてたっけ？」「前にメモしたやつ」「あのページ」
2. **プロジェクト固有の知識が必要なとき**: Plurality、plural reality、多元現実、デジタル民主主義、Polis、ガバナンスなどのトピック
3. **「スクボで調べて」「Scrapboxから探して」**: 明示的な検索依頼
4. **コンテキストが不足しているとき**: ユーザーの質問が曖昧で、Scrapboxに関連情報がありそうな場合

### 手動トリガー

- 「Scrapboxで調べて」「スクボ検索」「ナレッジベースから」

## 対応プロジェクト

Scrapbox の3プロジェクトは全部到達対象。境界はプライバシー階層であって検索禁止境界ではない。

| プロジェクト名 | 識別キーワード | 用途 |
|---|---|---|
| `plural-reality` | 「Plurality」「チーム」「plural reality」「多元現実」「法人」「契約」「経理」「法務」「Sonar」「Cartographer」「Flux」 | 多元現実の法人・チームナレッジ。契約、経理、法務、プロダクト、チーム日報、Beeper(zos) |
| `tkgshn-private` | 「プライベート」「個人メモ」「自分の」「日報」「研究メモ」 | 個人メモ。日報、Limitless、Typeless、Calendar、思想・研究メモ、日付ページ |
| `takalog` | 「人物」「人脈」「CRM」「会話ログ」「Claude会話」「案件の意思決定」 | 最機密・自分専用。人物/案件のエンティティページ、会話ログ、意思決定履歴 |

ユーザーが特にプロジェクトを指定しない場合:
- まず質問のエンティティ種別からプロジェクトを推測する。
- 法人の契約・財務・法務・プロダクトは `plural-reality` を起点にする。
- 個人メモ・日報・研究メモは `tkgshn-private` を起点にする。
- 人物、CRM、会話ログ、過去のAI会話、案件の意思決定履歴は `takalog` を外さない。
- 不明な場合は `plural-reality` / `tkgshn-private` / `takalog` を横断検索し、候補タイトルを見てから本文取得する。

## 読み取りコマンド

Scrapbox 本文取得に WebFetch を使わない。WebFetch は本文を要約・変形し、Scrapbox の行構造とリンク文脈を壊す。

canonical な読み取り窓口は `cosense-fetch`。

```bash
# 全文検索: 候補ページを探す
cosense-fetch -s "検索語" -p plural-reality -l 8
cosense-fetch -s "検索語" -p tkgshn-private -l 8
cosense-fetch -s "検索語" -p takalog -l 8

# ページ取得: 必要なページだけリンク展開込みで読む
cosense-fetch "ページタイトル" -p plural-reality -h 2

# 1ページの生JSON: 行・メタデータを保持して読む
cosense-fetch -r "ページタイトル" -p takalog

# SIDの有効性確認
cosense-fetch --me
```

`SCRAPBOX_SID` は環境変数として注入される。prompt、skill、Nix module に secret 値を直書きしない。

## live source 契約

Scrapbox は index / graph / note の層。最新の実体が別 tool にあるものは、Scrapbox だけで完結させない。

| エンティティ種別 | Scrapbox 起点 | 最新の実体 |
|---|---|---|
| 人物 | `takalog` の人物エンティティページ + 3プロジェクト横断検索 | Gmail、Beeper、pendant/Limitless 等の live tool |
| 案件/プロダクト | `plural-reality` + `takalog` | git repo、Supabase、Gmail、Drive、Scrapbox |
| 法人/契約/経理/法務 | `plural-reality` | freee、Gmail、Drive |
| メールスレッド | `takalog` の日付ページや index | Gmail / himalaya の thread 本文 |
| カレンダー予定 | 日付ページ Schedule | Apple Calendar / Google Calendar。本人の空き時間は Apple Calendar を読む |
| 会話/音声 | `tkgshn-private` 日報、Limitless/Typeless index | pendant/Limitless/Typeless の live data |
| チャット | `plural-reality` は zos 等の index | Beeper API、Slack/Gmail/iMessage 等の live data |
| 過去のAI会話 | `takalog`、Claude 会話ログ index | `ch` / Claude archive / local session files |

この表で「Scrapbox 起点」と「最新の実体」が分かれるものは、Scrapbox の候補だけで結論にしない。必要な live tool へ辿る。

## 検索戦略

1. ユーザーの語から固有名詞・人名・プロダクト名・日付・法人/契約/経理語彙を抽出する。
2. まず `cosense-fetch -s` で候補タイトルを探す。本文を一括ダンプしない。
3. 候補から必要なページだけ `cosense-fetch "タイトル" -p <project> -h 2` で読む。
4. 本文中の `https://scrapbox.io/<other>/<page>` の越境リンクは、同一 fetch の `-h 2` には入らない。`-p <other>` に切り替えて second fetch する。
5. ページが見つからない場合は、表記揺れ、英日、略称、日付ページ、関連人物名で検索する。
6. 情報の実体が live tool にある種別なら、Scrapbox を index として使い、対応する live tool で確認する。

## レスポンスフォーマット

取得した情報を回答に組み込む際:

1. **出典を明示する**: 「Scrapboxの[ページ名]によると...」
2. **リンクを提供する**: `https://scrapbox.io/PROJECT/PAGE_TITLE`
3. **1-hop/2-hop の関連ページにも言及する**: 「関連ページとして[X]や[Y]もあります」
4. **情報が古い可能性を示唆する**: 必要に応じて「最終更新日は不明ですが...」
5. **live tool へ辿った場合は境界を明示する**: 「Scrapbox は index、本文は Gmail で確認」など

## エラーハンドリング

- **404**: ページが見つからない → 表記揺れを試す or ページ一覧で検索
- **401/403**: `SCRAPBOX_SID` が期限切れ → `cosense-fetch --me` で確認し、期限切れならユーザーに SID 更新を依頼する
- **502**: Scrapbox API がダウン → 時間をおいて再試行

## 注意事項

- Scrapbox の内容はユーザーの個人メモを含むため、第三者に共有しないこと
- 大量のデータを取得する場合（2-hop）はコンテキストウィンドウの消費に注意
- `SCRAPBOX_SID` が期限切れの場合、`save-to-scrapbox` の書き込みも同時に失敗する
