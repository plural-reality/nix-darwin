/**
 * Narrow, fail-closed receipt attachment capability for freee deals.
 *
 * The command never accepts an arbitrary API path or request body. It only:
 *   1. reads one existing deal,
 *   2. uploads one validated local receipt via the official local freee-mcp,
 *   3. merges that file-box ID into that deal's receipt_ids, and
 *   4. reads the deal back and verifies invariant fields.
 *
 * JSON is read from stdin. `mode: "preview"` is non-mutating; only an explicit
 * `mode: "apply"` can upload or update freee.
 */
import { createHash } from "node:crypto";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  realpathSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { pathToFileURL } from "node:url";

type Json = null | boolean | number | string | readonly Json[] | { readonly [key: string]: Json };
type RecordValue = Readonly<Record<string, unknown>>;
type Result<T> = Readonly<{ ok: true; value: T }> | Readonly<{ ok: false; error: string }>;
type Mode = "preview" | "apply";
type ReceiptKind = "jpeg" | "png" | "pdf";

type ReceiptInput = Readonly<{
  issue_date: string;
  amount: number;
  partner_name: string;
  description: string;
  document_type?: "receipt";
}>;

type AttachInput = Readonly<{
  mode: Mode;
  company_id: string | number;
  deal_id: string | number;
  file_path: string;
  receipt: ReceiptInput;
  approval_token?: string;
}>;

type Source = Readonly<{
  path: string;
  filename: string;
  bytes: number;
  sha256: string;
  kind: ReceiptKind;
}>;

type LedgerRecord = Readonly<{
  company_id: string;
  deal_id: string;
  sha256: string;
  receipt_id: string;
  filename: string;
  created_at: string;
  verified_at?: string;
}>;

type Ledger = Readonly<{
  version: 1;
  records: Readonly<Record<string, LedgerRecord>>;
}>;

type DealSummary = Readonly<{
  id: string;
  company_id: string;
  issue_date: string;
  type: string;
  amount: number;
  due_amount: number | null;
  status: string | null;
  ref_number: string | null;
  partner_id: string | null;
  receipt_ids: readonly string[];
}>;

const maxBytes = 64 * 1024 * 1024;
const timeoutMs = 60_000;
const allowedRoots = [
  "/tmp/codex-remote-attachments",
  join(homedir(), "Documents", "Codex"),
  join(homedir(), ".codex", "visualizations"),
].map((root) => (existsSync(root) ? realpathSync(root) : root));
const ledgerPath = join(homedir(), ".local", "state", "freee-receipt-attach", "records.json");

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const asString = (value: unknown, field: string): string => {
  if (typeof value !== "string" || value.trim() === "") throw new Error(`${field} must be a non-empty string`);
  return value;
};

const asPositiveInteger = (value: unknown, field: string): number => {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isSafeInteger(n) || n <= 0) throw new Error(`${field} must be a positive integer`);
  return n;
};

const asId = (value: unknown, field: string): string => String(asPositiveInteger(value, field));

const dateOf = (value: unknown, field: string): string => {
  const date = asString(value, field);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(Date.parse(`${date}T00:00:00Z`))) {
    throw new Error(`${field} must be YYYY-MM-DD`);
  }
  return date;
};

const boundedText = (value: unknown, field: string, maximum: number): string => {
  const text = asString(value, field).trim();
  if (text.length > maximum) throw new Error(`${field} must be at most ${maximum} characters`);
  return text;
};

export const parseAttachInput = (value: unknown): AttachInput => {
  if (!isRecord(value)) throw new Error("input must be a JSON object");
  const receipt = value.receipt;
  if (!isRecord(receipt)) throw new Error("receipt must be a JSON object");
  const mode = value.mode === "preview" || value.mode === "apply" ? value.mode : null;
  if (!mode) throw new Error('mode must be "preview" or "apply"');
  const documentType = receipt.document_type;
  if (typeof documentType !== "undefined" && documentType !== "receipt") {
    throw new Error('receipt.document_type, when present, must be "receipt"');
  }
  const approvalToken = value.approval_token;
  if (typeof approvalToken !== "undefined" && (typeof approvalToken !== "string" || !/^[a-f0-9]{64}$/.test(approvalToken))) {
    throw new Error("approval_token must be a SHA-256 token returned by preview");
  }
  return {
    mode,
    company_id: asId(value.company_id, "company_id"),
    deal_id: asId(value.deal_id, "deal_id"),
    file_path: asString(value.file_path, "file_path"),
    receipt: {
      issue_date: dateOf(receipt.issue_date, "receipt.issue_date"),
      amount: asPositiveInteger(receipt.amount, "receipt.amount"),
      partner_name: boundedText(receipt.partner_name, "receipt.partner_name", 255),
      description: boundedText(receipt.description, "receipt.description", 255),
      document_type: "receipt",
    },
    ...(approvalToken ? { approval_token: approvalToken } : {}),
  };
};

const hasPrefix = (path: string, root: string): boolean => path === root || path.startsWith(`${root}/`);

const kindOf = (bytes: Buffer): ReceiptKind =>
  bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff
    ? "jpeg"
    : bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
      ? "png"
      : bytes.length >= 5 && bytes.subarray(0, 5).toString("ascii") === "%PDF-"
        ? "pdf"
        : (() => {
            throw new Error("receipt file must be a JPEG, PNG, or PDF");
          })();

export const inspectSource = (rawPath: string): Source => {
  const absolute = resolve(rawPath);
  if (!existsSync(absolute)) throw new Error(`receipt file does not exist: ${absolute}`);
  const path = realpathSync(absolute);
  if (!allowedRoots.some((root) => hasPrefix(path, root))) {
    throw new Error(`receipt file must be under an approved receipt directory: ${allowedRoots.join(", ")}`);
  }
  const stat = statSync(path);
  if (!stat.isFile()) throw new Error("receipt file must be a regular file");
  if (stat.size <= 0 || stat.size > maxBytes) throw new Error(`receipt file must be between 1 byte and ${maxBytes} bytes`);
  const bytes = readFileSync(path);
  return {
    path,
    filename: basename(path),
    bytes: stat.size,
    sha256: createHash("sha256").update(bytes).digest("hex"),
    kind: kindOf(bytes),
  };
};

const safeError = (value: unknown): string =>
  String(value instanceof Error ? value.message : value)
    .replace(/Bearer\s+[^\s]+/gi, "Bearer [REDACTED]")
    .replace(/[\r\n]+/g, " ")
    .slice(0, 900);

const readJson = (path: string): unknown => JSON.parse(readFileSync(path, "utf8"));

const stateKey = (companyId: string, dealId: string, sha256: string): string => `${companyId}:${dealId}:${sha256}`;

const emptyLedger = (): Ledger => ({ version: 1, records: {} });

const loadLedger = (): Ledger => {
  if (!existsSync(ledgerPath)) return emptyLedger();
  try {
    const parsed = readJson(ledgerPath);
    if (!isRecord(parsed) || parsed.version !== 1 || !isRecord(parsed.records)) return emptyLedger();
    const records = Object.entries(parsed.records).reduce<Record<string, LedgerRecord>>((acc, [key, value]) => {
      if (
        isRecord(value) &&
        typeof value.company_id === "string" &&
        typeof value.deal_id === "string" &&
        typeof value.sha256 === "string" &&
        typeof value.receipt_id === "string" &&
        typeof value.filename === "string" &&
        typeof value.created_at === "string"
      ) {
        acc[key] = value as LedgerRecord;
      }
      return acc;
    }, {});
    return { version: 1, records };
  } catch {
    throw new Error("receipt attachment ledger is malformed; refusing an ambiguous retry");
  }
};

const saveLedger = (ledger: Ledger): void => {
  mkdirSync(dirname(ledgerPath), { recursive: true, mode: 0o700 });
  const temporary = `${ledgerPath}.${process.pid}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(ledger, null, 2)}\n`, { mode: 0o600 });
  renameSync(temporary, ledgerPath);
};

const updateLedger = (entry: LedgerRecord): Ledger => {
  const ledger = loadLedger();
  const key = stateKey(entry.company_id, entry.deal_id, entry.sha256);
  const next: Ledger = { version: 1, records: { ...ledger.records, [key]: entry } };
  saveLedger(next);
  return next;
};

const numberField = (value: unknown, field: string): number => {
  const result = Number(value);
  if (!Number.isFinite(result)) throw new Error(`${field} must be numeric in the deal response`);
  return result;
};

const idFrom = (value: unknown): string | null =>
  isRecord(value) && (typeof value.id === "number" || typeof value.id === "string") ? String(value.id) : null;

const receiptIdsOf = (deal: RecordValue): readonly string[] => {
  const values = Array.isArray(deal.receipts) ? deal.receipts : [];
  return values.flatMap((value) => {
    const id = idFrom(value);
    return id ? [id] : [];
  });
};

const summaryOf = (deal: RecordValue): DealSummary => ({
  id: asId(deal.id, "deal.id"),
  company_id: asId(deal.company_id, "deal.company_id"),
  issue_date: dateOf(deal.issue_date, "deal.issue_date"),
  type: asString(deal.type, "deal.type"),
  amount: numberField(deal.amount, "deal.amount"),
  due_amount: deal.due_amount === null || typeof deal.due_amount === "undefined" ? null : numberField(deal.due_amount, "deal.due_amount"),
  status: typeof deal.status === "string" ? deal.status : null,
  ref_number: typeof deal.ref_number === "string" ? deal.ref_number : null,
  partner_id: deal.partner_id === null || typeof deal.partner_id === "undefined" ? null : asId(deal.partner_id, "deal.partner_id"),
  receipt_ids: receiptIdsOf(deal),
});

const requireSafeTarget = (input: AttachInput, deal: RecordValue): DealSummary => {
  const summary = summaryOf(deal);
  if (summary.id !== String(input.deal_id)) throw new Error("read-back deal ID does not match deal_id");
  if (summary.company_id !== String(input.company_id)) throw new Error("read-back company ID does not match company_id");
  if (summary.type !== "expense") throw new Error("only expense deals may receive a receipt through this capability");
  if (summary.issue_date !== input.receipt.issue_date) throw new Error("receipt.issue_date does not match the target deal issue_date");
  if (summary.amount !== input.receipt.amount) throw new Error("receipt.amount does not match the target deal amount");
  if (!Array.isArray(deal.details) || deal.details.length === 0) throw new Error("target deal has no details; refusing an unsafe update");
  return summary;
};

const fieldsOfDetail = (detail: unknown): Record<string, unknown> => {
  if (!isRecord(detail)) throw new Error("deal.details contains a malformed detail");
  const required = ["id", "account_item_id", "tax_code", "amount"] as const;
  required.forEach((key) => {
    if (detail[key] === null || typeof detail[key] === "undefined") throw new Error(`deal detail is missing ${key}`);
  });
  const supported = [
    "id",
    "account_item_id",
    "tax_code",
    "partner_id",
    "item_id",
    "section_id",
    "tag_ids",
    "amount",
    "description",
    "entry_side",
  ] as const;
  return supported.reduce<Record<string, unknown>>((acc, key) => {
    if (detail[key] !== null && typeof detail[key] !== "undefined") acc[key] = detail[key];
    return acc;
  }, {});
};

const unique = (values: readonly string[]): readonly string[] => [...new Set(values)];

export const buildDealUpdate = (input: AttachInput, deal: RecordValue, receiptId: string): Record<string, unknown> => {
  const summary = requireSafeTarget(input, deal);
  const body: Record<string, unknown> = {
    company_id: Number(summary.company_id),
    issue_date: summary.issue_date,
    type: summary.type,
    details: (deal.details as readonly unknown[]).map(fieldsOfDetail),
    receipt_ids: unique([...summary.receipt_ids, receiptId]).map((id) => Number(id)),
  };
  if (summary.partner_id) body.partner_id = Number(summary.partner_id);
  if (summary.ref_number) body.ref_number = summary.ref_number;
  return body;
};

const detailFingerprint = (deal: RecordValue): string =>
  JSON.stringify((deal.details as readonly unknown[]).map(fieldsOfDetail));

const assertVerified = (before: RecordValue, after: RecordValue, receiptId: string): DealSummary => {
  const oldSummary = summaryOf(before);
  const newSummary = summaryOf(after);
  const fixed = ["id", "company_id", "issue_date", "type", "amount", "due_amount", "status", "ref_number", "partner_id"] as const;
  fixed.forEach((field) => {
    if (oldSummary[field] !== newSummary[field]) throw new Error(`post-update invariant changed: ${field}`);
  });
  if (detailFingerprint(before) !== detailFingerprint(after)) throw new Error("post-update deal details differ from the pre-update read-back");
  const missingPrevious = oldSummary.receipt_ids.filter((id) => !newSummary.receipt_ids.includes(id));
  if (missingPrevious.length > 0) throw new Error("post-update receipt list lost an existing attachment");
  if (!newSummary.receipt_ids.includes(receiptId)) throw new Error("post-update receipt list does not contain the uploaded receipt ID");
  return newSummary;
};

const textOfMcpResult = (value: unknown): string => {
  if (!isRecord(value) || !Array.isArray(value.content)) throw new Error("freee MCP returned an invalid tool response");
  const texts = value.content.flatMap((part) => (isRecord(part) && part.type === "text" && typeof part.text === "string" ? [part.text] : []));
  const text = texts.join("\n");
  if (value.isError === true) throw new Error(`freee MCP reported an error: ${safeError(text)}`);
  return text;
};

const jsonFromToolText = (text: string): RecordValue => {
  const trimmed = text.trim();
  const starts = [...trimmed].flatMap((character, index) => (character === "{" || character === "[" ? [index] : []));
  for (const start of starts) {
    try {
      const parsed = JSON.parse(trimmed.slice(start));
      if (isRecord(parsed)) return parsed;
    } catch {
      // A human-readable prefix is normal for freee_file_upload; try its JSON suffix.
    }
  }
  throw new Error("freee MCP tool response did not contain a JSON object");
};

class McpClient {
  private readonly process: ChildProcessWithoutNullStreams;
  private readonly pending = new Map<number, { resolve: (value: unknown) => void; reject: (error: Error) => void; timer: NodeJS.Timeout }>();
  private nextId = 1;

  private constructor(process: ChildProcessWithoutNullStreams) {
    this.process = process;
    const lines = createInterface({ input: process.stdout });
    lines.on("line", (line) => {
      try {
        const message = JSON.parse(line) as unknown;
        if (!isRecord(message) || typeof message.id !== "number") return;
        const pending = this.pending.get(message.id);
        if (!pending) return;
        this.pending.delete(message.id);
        clearTimeout(pending.timer);
        if (message.error) pending.reject(new Error(`freee MCP RPC error: ${safeError(JSON.stringify(message.error))}`));
        else pending.resolve(message.result);
      } catch {
        // MCP stdout is protocol-only. Ignore a malformed non-protocol line rather than treating it as a response.
      }
    });
    process.once("error", (error) => this.rejectAll(error));
    process.once("exit", (code, signal) => this.rejectAll(new Error(`freee MCP exited before completion (code=${code}, signal=${signal})`)));
  }

  static async start(): Promise<McpClient> {
    const command = process.env.FREEE_MCP_BIN;
    if (!command || !existsSync(command)) throw new Error("FREEE_MCP_BIN is not configured to an executable official local freee-mcp");
    const childProcess = spawn(command, [], { stdio: ["pipe", "pipe", "pipe"], env: process.env });
    const client = new McpClient(childProcess);
    await client.request("initialize", {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: { name: "freee-receipt-attach", version: "1.0.0" },
    });
    client.notify("notifications/initialized", {});
    return client;
  }

  private rejectAll(error: Error): void {
    this.pending.forEach((pending) => {
      clearTimeout(pending.timer);
      pending.reject(error);
    });
    this.pending.clear();
  }

  private request(method: string, params: Record<string, unknown>): Promise<unknown> {
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`freee MCP timeout: ${method}`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      this.process.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    });
  }

  private notify(method: string, params: Record<string, unknown>): void {
    this.process.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`);
  }

  async call(name: string, arguments_: Record<string, unknown>): Promise<RecordValue> {
    const result = await this.request("tools/call", { name, arguments: arguments_ });
    return jsonFromToolText(textOfMcpResult(result));
  }

  close(): void {
    this.process.kill();
  }
}

const dealFrom = (response: RecordValue): RecordValue => {
  if (!isRecord(response.deal)) throw new Error("freee response did not contain deal");
  return response.deal;
};

const readDeal = async (client: McpClient, input: AttachInput): Promise<RecordValue> =>
  dealFrom(
    await client.call("freee_api_get", {
      service: "accounting",
      path: `/api/1/deals/${input.deal_id}`,
      query: { company_id: Number(input.company_id) },
    }),
  );

const receiptIdFrom = (response: RecordValue): string => {
  const receipt = isRecord(response.receipt) ? response.receipt : response;
  return asId(receipt.id, "uploaded receipt.id");
};

const approvalTokenOf = (target: DealSummary, source: Source, deal: RecordValue): string =>
  createHash("sha256")
    .update(JSON.stringify({ target, source_sha256: source.sha256, details: detailFingerprint(deal) }))
    .digest("hex");

const preview = (input: AttachInput, source: Source, deal: RecordValue, saved: LedgerRecord | undefined): Record<string, unknown> => {
  const target = requireSafeTarget(input, deal);
  const alreadyAttached = saved ? target.receipt_ids.includes(saved.receipt_id) : false;
  return {
    ok: true,
    mode: "preview",
    target,
    source,
    approval_token: approvalTokenOf(target, source, deal),
    ledger: saved
      ? { state: alreadyAttached ? "verified" : "uploaded_unattached", receipt_id: saved.receipt_id }
      : { state: "no_prior_upload" },
    planned_effect: alreadyAttached
      ? "no mutation; this exact source hash is already attached to this deal"
      : saved
        ? "reuse the recorded file-box ID; attach it to this one deal"
        : "upload this one file to the freee file box and attach its new ID to this one deal",
  };
};

const run = async (input: AttachInput): Promise<Record<string, unknown>> => {
  const source = inspectSource(input.file_path);
  const ledger = loadLedger();
  const key = stateKey(String(input.company_id), String(input.deal_id), source.sha256);
  const saved = ledger.records[key];
  const client = await McpClient.start();
  try {
    const before = await readDeal(client, input);
    const check = preview(input, source, before, saved);
    if (input.mode === "preview") return check;
    const approvalToken = approvalTokenOf(requireSafeTarget(input, before), source, before);
    if (input.approval_token !== approvalToken) {
      throw new Error("mode apply requires the approval_token returned by an unchanged preview");
    }
    if (saved && summaryOf(before).receipt_ids.includes(saved.receipt_id)) {
      return { ...check, mode: "apply", result: "already_attached", receipt_id: saved.receipt_id };
    }

    const receiptId = saved
      ? saved.receipt_id
      : receiptIdFrom(
          await client.call("freee_file_upload", {
            file_path: source.path,
            company_id: Number(input.company_id),
            document_type: "receipt",
            description: input.receipt.description,
            receipt_metadatum_partner_name: input.receipt.partner_name,
            receipt_metadatum_issue_date: input.receipt.issue_date,
            receipt_metadatum_amount: input.receipt.amount,
          }),
        );

    if (!saved) {
      updateLedger({
        company_id: String(input.company_id),
        deal_id: String(input.deal_id),
        sha256: source.sha256,
        receipt_id: receiptId,
        filename: source.filename,
        created_at: new Date().toISOString(),
      });
    }

    await client.call("freee_api_put", {
      service: "accounting",
      path: `/api/1/deals/${input.deal_id}`,
      body: buildDealUpdate(input, before, receiptId),
    });

    const after = await readDeal(client, input);
    const verified = assertVerified(before, after, receiptId);
    updateLedger({
      company_id: String(input.company_id),
      deal_id: String(input.deal_id),
      sha256: source.sha256,
      receipt_id: receiptId,
      filename: source.filename,
      created_at: saved?.created_at ?? new Date().toISOString(),
      verified_at: new Date().toISOString(),
    });
    return { ok: true, mode: "apply", result: "attached_and_verified", receipt_id: receiptId, target: verified, source };
  } finally {
    client.close();
  }
};

const main = async (): Promise<number> => {
  if (process.argv.includes("--self-test")) {
    const input = parseAttachInput({
      mode: "preview",
      company_id: 12669261,
      deal_id: 1,
      file_path: "/tmp/codex-remote-attachments/example.jpg",
      receipt: { issue_date: "2026-09-02", amount: 100, partner_name: "test", description: "test" },
    });
    if (input.receipt.document_type !== "receipt") throw new Error("self-test failed");
    process.stdout.write('{"ok":true,"self_test":"passed"}\n');
    return 0;
  }
  try {
    const parsed = parseAttachInput(JSON.parse(readFileSync(0, "utf8")));
    process.stdout.write(`${JSON.stringify(await run(parsed), null, 2)}\n`);
    return 0;
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ ok: false, error: safeError(error) })}\n`);
    return 1;
  }
};

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().then((code) => {
    process.exitCode = code;
  });
}
