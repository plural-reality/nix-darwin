import assert from "node:assert/strict";
import test from "node:test";

import { buildDealUpdate, parseAttachInput } from "./freee-receipt-attach.ts";

const input = parseAttachInput({
  mode: "apply",
  company_id: 12669261,
  deal_id: 3757958566,
  file_path: "/tmp/codex-remote-attachments/a.jpg",
  receipt: {
    issue_date: "2026-09-02",
    amount: 3828,
    partner_name: "オカモトセルフ名寄徳田店",
    description: "音威子府出張のガソリン代",
  },
});

const deal = {
  id: 3757958566,
  company_id: 12669261,
  issue_date: "2026-09-02",
  type: "expense",
  amount: 3828,
  due_amount: 3828,
  status: "unsettled",
  ref_number: "EXP-202609-001",
  partner_id: 123,
  receipts: [{ id: 9 }],
  details: [
    {
      id: 111,
      account_item_id: 1051646033,
      tax_code: 2,
      partner_id: 123,
      tag_ids: [],
      amount: 3828,
      description: "existing detail",
      entry_side: "debit",
    },
  ],
};

test("buildDealUpdate preserves every existing detail and existing receipt IDs", () => {
  const body = buildDealUpdate(input, deal, "10");
  assert.deepEqual(body.receipt_ids, [9, 10]);
  assert.deepEqual(body.details, deal.details);
  assert.equal(body.company_id, 12669261);
  assert.equal(body.ref_number, "EXP-202609-001");
  assert.equal(body.partner_id, 123);
});

test("rejects unsafe date, amount, and document type", () => {
  assert.throws(
    () => parseAttachInput({ ...input, receipt: { ...input.receipt, issue_date: "2026/09/02" } }),
    /YYYY-MM-DD/,
  );
  const mismatchedAmount = parseAttachInput({ ...input, receipt: { ...input.receipt, amount: 3827 } });
  assert.throws(() => buildDealUpdate(mismatchedAmount, deal, "10"), /does not match/);
  assert.throws(
    () => parseAttachInput({ ...input, receipt: { ...input.receipt, document_type: "invoice" } }),
    /document_type/,
  );
});

test("requires a well-formed preview approval token when one is supplied", () => {
  assert.throws(
    () => parseAttachInput({ ...input, approval_token: "not-a-preview-token" }),
    /approval_token/,
  );
});

test("refuses to overwrite a deal when its receipt metadata is inconsistent", () => {
  assert.throws(() => buildDealUpdate(input, { ...deal, amount: 3827 }, "10"), /does not match/);
  assert.throws(() => buildDealUpdate(input, { ...deal, type: "income" }, "10"), /only expense/);
});
