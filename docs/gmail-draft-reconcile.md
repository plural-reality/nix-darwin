# Gmail residual draft reconciliation

The account owner authorized ongoing cleanup of already-sent draft versions on 2026-09-09. `gmail-draft-reconcile` reconciles an explicitly selected Gmail account. The downstream configuration enables a 300-second LaunchAgent on Mini for corporate mail only. No sending, account changes, memory/style learning, thread trashing or permanent-delete endpoint is implemented.

## Decision and mutation boundary

Every run verifies `users.getProfile` against the configured account. A draft must be unchanged across observations at least 120 seconds apart and older than a verified SENT message; the send must be at least 120 seconds old and within the last 30 days, with at most 30 days between draft and send. Exact To, From, subject, In-Reply-To and Reply-To must match; sent Cc/Bcc may add recipients but cannot omit draft recipients.

Full MIME text representations (including raw HTML, quoted text and suffixes) determine exact matches. For edited prose a similarity prefilter is necessary but never sufficient: numeric token order, URLs and attachment bytes are checked, then a tool-free Claude subprocess must affirm same intent, no unsent request and no contradiction. It receives only the fixed pair, cannot select IDs or mutate mail, has all tools/skills/MCP removed, uses an empty temporary working directory and disables local session persistence. The parent strictly validates JSON booleans. It uses existing Claude authentication; no credential is created. Provider-side retention follows the existing account's terms. Managed policies remain effective; authentication/policy/format errors and 45-second timeouts mean hold.

There are at most 3 model comparisons, 100 Gmail requests, 100 listed drafts, 50 candidate sent messages per recipient and 5 mutations per run. Oversized/external body parts and compound, encrypted or signed attachments are held. A later draft, changed recipients/facts, unclear classification and concurrent edits are held. No model decision overrides a hard guard.

The runner locks a 0700 local state directory. It rereads the original draft and sent message after classification, compares fingerprints, records a durable intent, and trashes only the original message ID. It verifies TRASH, absence from the draft list, and the sent original's SENT label. Interrupted mutations are verified on the next run before further writes. Receipts retain IDs/hashes/reasons, never email bodies. An unresolved receipt stops mutation for review.

## Operation

The declarative downstream LaunchAgent owns the schedule and executable paths. `gmail-draft-reconcile status` reports the last run and receipts. `run --account ACCOUNT --gws PATH` is audit-only; `--apply` enables trash. `--classifier PATH` enables conservative edited-prose checks; without it only exact matches can act. Classifier unavailability leaves edited drafts visible in `deferred` with `meaning_not_confirmed`.

The first observation waits for a later run, so residual drafts normally disappear about 5–10 minutes after sending while Mini is awake. No repeated send or draft creation is used as a test. To investigate an incorrectly held item, read the live messages by the reported IDs. To restore a trashed message, use Gmail's Trash or `messages.untrash` on its exact message ID, then read back; restoration of the original draft resource must be verified separately. Gmail Trash has finite retention and is not an archive.

## Validation

`python3 -m unittest discover -s scripts/claude -p test_gmail_draft_reconcile.py`

Tests cover original draft consumption, no-op repetition, account mismatch, recipient/reply changes, changed amounts/order/URLs, suffixes, plain/HTML alternatives, unnamed and compound attachments, concurrent edits, semantic gating, classifier failure/timeout, and interrupted mutation readback. Deployment also checks synthetic style vs opposite-decision classification from launchd and canonical Gmail state. Synthetic tests are evidence of bounded behavior, not a guarantee of semantic classification accuracy; ambiguous mail remains for review.

## Primary sources and choice

- [Gmail drafts lifecycle](https://developers.google.com/workspace/gmail/api/guides/drafts): stable draft ID, replaced inner message ID, `drafts.send` consumes the saved draft. Agent sends should use that API after approval.
- [Gmail push notifications](https://developers.google.com/workspace/gmail/api/guides/push): notifications may be delayed/dropped and require reconciliation. One small mailbox does not justify adding Pub/Sub and watch renewal; bounded polling also catches sends from Apple Mail.
- [messages.trash](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/trash): target the individual residual message. `drafts.delete` is not used because it permanently deletes the draft.
- [Claude CLI reference](https://code.claude.com/docs/en/cli-reference): restricted mode, empty tools, wildcard disallowed tools, strict empty MCP configuration and session non-persistence. StructuredOutput itself is a tool, so this runner uses plain JSON text with strict parent validation instead of enabling that tool.
