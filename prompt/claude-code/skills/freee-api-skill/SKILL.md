---
name: freee-api-skill
description: >
  Use for freee accounting, HR, invoice, PM, sales, and freee MCP/API work.
  Prefer the token-efficient `freee-call` CLI for known endpoints and compact
  reads; use MCP only for discovery, unfamiliar payload shapes, or operations
  where the MCP wrapper is materially safer.
---

# freee API

freee work must use one current company as the data boundary. In this environment
the OAuth state lives in `~/.config/freee-mcp`; do not print tokens or copy them
into repo files.

## Call Policy

1. Use `freee-call` first when the service and endpoint are known.
2. Use shell composition (`freee-call | jq ...`) to reduce output before showing
   it to the model.
3. Use `freee_get_current_company` or `freee-call` against `/api/1/companies`
   once per session, then reuse the company boundary.
4. Use `freee_api_list_paths` only when the endpoint is unknown.
5. Read recipes or references only when the request body, endpoint semantics, or
   an API error requires it.
6. Before mutation, state the target company, endpoint, and compact payload
   summary. Avoid broad parallel writes unless the entities are independent.

## `freee-call`

`freee-call` is a stream filter: JSON in, JSON out. It reads the local
`freee-mcp` OAuth files, refreshes tokens when needed, and calls freee REST
directly. It defaults `service` to `accounting`, `method` to `GET`, and injects
the current `company_id` from `~/.config/freee-mcp/config.json` unless
`company_id` is set to `false`.

Examples:

```bash
printf '%s\n' '{"path":"/api/1/companies"}' | freee-call

printf '%s\n' '{"path":"/api/1/deals","query":{"limit":20}}' \
  | freee-call \
  | jq '{deals: [.deals[] | {id, issue_date, amount, status, partner_id}]}'

printf '%s\n' '{"service":"invoice","path":"/invoices","query":{"limit":20}}' \
  | freee-call \
  | jq .
```

For POST/PUT/PATCH/DELETE, pass `method` and `body`:

```bash
printf '%s\n' '{"method":"POST","path":"/api/1/partners","body":{"name":"取引先名","company_id":123456789}}' \
  | freee-call \
  | jq .
```

Replace `123456789` with the current company id from `/api/1/companies`.

### Bulk writes: NDJSON batch (never loop one-by-one)

When you have many same-shape writes (user_matchers, partners, deals, …), do NOT
call MCP or `freee-call` once per record — that bleeds context. `freee-call` also
accepts **NDJSON (one request per line) or a top-level JSON array**, runs them
sequentially, and emits `{i,ok,result|error}` per line. One bad line never aborts
the rest.

```bash
jq -nc '["取引先A","取引先B"][]
  | {method:"POST", path:"/api/1/partners", body:{name:.}}' \
  | freee-call \
  | jq -c 'select(.ok|not)'   # show only failures
```

Idempotency is the caller's job (keep `freee-call` a pure transport): GET existing
records, diff by natural key, pipe only the new requests. See
`references/user_matchers.md` for the full bulk + idempotent + reconcile recipe.

### Reconciliation: `freee-reconcile`

Bank balance vs registered deals in one call (no manual jq + mental arithmetic).
A txn is unregistered (未登録) iff `due_amount > 0`; `current_balance` is the
latest txn's running `balance`.

```bash
printf '%s\n' '{"walletable_id":4772220,"start_date":"2026-05-01","end_date":"2026-05-31"}' \
  | freee-reconcile \
  | jq '{current_balance, unregistered_count, unregistered_total}'
```

## MCP Fallback

Use MCP when:

- the endpoint path is unknown;
- the payload shape is uncertain and a recipe/reference is needed;
- the API response indicates a freee-specific semantic constraint;
- file upload is required.

Do not repeatedly call MCP just to list schemas or dump large responses. Once an
endpoint is identified, switch back to `freee-call` and `jq`.
