# user_matchers (自動経理ルール) + バルク書き込みレシピ

`user_matcher` は「明細の摘要が X を含むなら勘定科目 Y・税区分 Z で登録する」という
自動仕訳ルール。`partners`（取引先）と並んで、月次決算で**同型データを大量に
作る**典型。1件ずつ MCP / `freee-call` を叩くのではなく、必ず NDJSON バッチで畳む。

## 1. 確認済みフィールド形状 (GET レスポンス)

`GET /api/1/user_matchers` の `user_matchers[].data[]` 要素（実データ）:

```json
{
  "id": 78026348,
  "entry_side_str": "income",          // "income" | "expense"
  "description": "シヤ）コウソウニツポン", // 明細摘要のマッチ文字列
  "condition": 0,                       // 0 = 部分一致(含む)
  "priority": 41,                       // ルール適用優先度 (小さいほど先)
  "act": 1,                             // 1 = 登録アクション
  "min_amount": 5000000,               // 金額下限 (任意 / null)
  "max_amount": null,                   // 金額上限 (任意 / null)
  "deal_description": "劣後ローン借入金", // 生成される取引のメモ
  "active": true,
  "account_item_name": "長期借入金",     // GET は *_name エコー、POST は *_id
  "partner_name": "一般社団法人構想日本",
  "tax_name": "対象外"
}
```

## 2. POST/PUT ボディ (今週 154 件作成で実証済みの形)

GET は `*_name` を返すが、**書き込みは `*_id` を渡す**。最小ボディ:

```json
{
  "company_id": 12669261,
  "entry_side_str": "expense",
  "description": "SUPABASE",
  "account_item_id": 1051646034,
  "tax_code": 2,
  "act": 1,
  "condition": 0
}
```

任意で `priority` / `min_amount` / `max_amount` / `partner_id` / `deal_description`
/ `active` を付与。`tax_code` は `GET /api/1/taxes/companies/{id}` の `code`
（対象外=2 等）、`account_item_id` は `GET /api/1/account_items` の `id`。

更新は `PUT /api/1/user_matchers/{id}`、削除は `DELETE`。

## 3. バルク書き込み = `freee-call` NDJSON バッチ (★canonical)

`freee-call` は単一 JSON でも**NDJSON / JSON 配列**でも受ける。複数行を渡すと
逐次実行し、`{i,ok,result|error}` を1行ずつ返す。**1件の失敗で全体は止まらない**。
154 件の MCP 往復が1コマンドに畳まれる（=コンテキストに載らない）。

```bash
# {description -> account_item_id,tax_code,entry_side_str} の表からボディを生成し、
# NDJSON にして一括 POST。company_id は freee-call が自動注入する。
jq -nc '
  [ {d:"SUPABASE",        a:1051646034, t:2, s:"expense"},
    {d:"サイボウズ",        a:1051646050, t:2, s:"expense"} ]
  | .[] | {method:"POST", path:"/api/1/user_matchers",
           body:{entry_side_str:.s, description:.d,
                 account_item_id:.a, tax_code:.t, act:1, condition:0}}' \
| freee-call \
| jq -c 'select(.ok|not)'   # 失敗行だけ確認 (全成功なら無出力)
```

`partners` も同じ:

```bash
jq -nc '["高木俊輔","一般社団法人構想日本"][]
  | {method:"POST", path:"/api/1/partners", body:{name:.}}' \
| freee-call | jq -c '{i, ok, id:(.result.partner.id // .error)}'
```

## 4. 冪等性は「呼び出し側の関心事」(transport を汚さない)

`freee-call` は純粋な transport（read-before-write を内蔵しない）。再実行で
二重作成しないため、**生成段階で自然キーで差分を取る**。これが冪等化の正しい層。

```bash
# 既存の description 集合を取り、未登録のものだけ POST する (user_matchers)
existing=$(printf '%s\n' '{"path":"/api/1/user_matchers","query":{"limit":100}}' \
  | freee-call | jq '[.user_matchers[].data[].description]')

jq -nc --argjson seen "$existing" '
  [ {d:"SUPABASE",a:1051646034,t:2,s:"expense"},
    {d:"NEW VENDOR",a:1051646050,t:2,s:"expense"} ]
  | map(select(.d as $d | ($seen|index($d))|not))
  | .[] | {method:"POST", path:"/api/1/user_matchers",
           body:{entry_side_str:.s, description:.d, account_item_id:.a,
                 tax_code:.t, act:1, condition:0}}' \
| freee-call | jq -c '{i, ok}'
```

partners は `name`、deals は `ref_number` 等、エンティティの自然キーで同様に差分。

## 5. 照合 (残高 vs 登録済み) は `freee-reconcile`

未登録明細の検知は手 jq ではなく `freee-reconcile`:

```bash
printf '%s\n' '{"walletable_id":4772220,"start_date":"2026-05-01","end_date":"2026-05-31"}' \
  | freee-reconcile \
  | jq '{current_balance, unregistered_count, unregistered_total, unregistered_txns}'
```

`due_amount > 0` が未登録（未消込）。`unregistered_txns` を user_matcher 化 →
バッチ POST → 再 `freee-reconcile` で `unregistered_count: 0` を確認、が決算ループ。
