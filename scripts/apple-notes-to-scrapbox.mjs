#!/usr/bin/env node
// Apple Notes -> Scrapbox one-way stream bridge.
// Storage-specific extraction is isolated to `export`; classify/write stay JSONL filters.

import { createHash } from "node:crypto";
import { readFileSync, realpathSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const DEFAULT_ACCOUNT = "iCloud";
export const DEFAULT_FOLDER = "Scrapbox Sync";
export const DEFAULT_TITLE_PREFIX = "[Appleメモ]";
export const REVIEW_TITLE_PREFIX = "[Appleメモ:要手動確認]";
export const PRIVATE_PROJECT = "tkgshn-private";
export const TAKALOG_PROJECT = "takalog";

const valueOptions = new Set(["account", "folder", "limit", "title-prefix"]);

export const parseOptions = (tokens) =>
  tokens.reduce(
    (state, token, index, source) =>
      state.skipNext
        ? { ...state, skipNext: false }
        : token.startsWith("--") && valueOptions.has(token.slice(2))
          ? { ...state, [token.slice(2)]: source[index + 1] ?? "", skipNext: true }
          : token.startsWith("--")
            ? { ...state, [token.slice(2)]: true }
            : { ...state, _: [...state._, token] },
    { _: [], skipNext: false },
  );

export const sha256 = (text) => createHash("sha256").update(text, "utf8").digest("hex");
export const shortHash = (text) => sha256(text).slice(0, 10);
export const oneLine = (text) => String(text ?? "").replace(/\s+/g, " ").trim();
export const titleCore = (title) => oneLine(title).slice(0, 64) || "Untitled";
export const sourceKey = (note) => shortHash(note.id ?? `${note.account}/${note.folder}/${note.title}`);
export const pageTitle = (note, classification, titlePrefix = DEFAULT_TITLE_PREFIX) =>
  `${classification.blocked ? REVIEW_TITLE_PREFIX : titlePrefix} ${titleCore(note.title)} ${sourceKey(note)}`;

const matchLabels = (rules, text) =>
  rules.filter(({ pattern }) => pattern.test(text)).map(({ label }) => label);

const secretRules = [
  { label: "private-key", pattern: /-----BEGIN (?:OPENSSH|RSA|DSA|EC|PRIVATE) KEY-----/i },
  { label: "auth-secret", pattern: /\b(?:password|passwd|api[_ -]?key|secret|access[_ -]?token|refresh[_ -]?token|otp|2fa|backup code)\b/i },
  { label: "auth-secret-ja", pattern: /(?:パスワード|秘密鍵|認証コード|二段階認証|バックアップコード|APIキー)/ },
  { label: "url-token", pattern: /[?&](?:token|key|code|secret|access_token|refresh_token)=/i },
  { label: "my-number-like", pattern: /(?:マイナンバー|個人番号).{0,16}\d{4}\s?\d{4}\s?\d{4}/ },
];

const sensitiveRules = [
  { label: "email", pattern: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i },
  { label: "phone", pattern: /(?:\+81[-\s]?)?0[789]0[-\s]?\d{4}[-\s]?\d{4}/ },
  { label: "postal-code", pattern: /〒?\d{3}-?\d{4}/ },
  { label: "address-prefecture", pattern: /(北海道|東京都|京都府|大阪府|.{2,3}県).{0,30}(市|区|町|村)/ },
  { label: "address-detail", pattern: /(住所|所在地|自宅|実家|マンション|アパート|号室|丁目|番地)/ },
  { label: "bank-payment", pattern: /(銀行|支店|口座|振込|入金|出金|IBAN|SWIFT|カード番号|請求|領収|freee|納付)/i },
  { label: "legal-contract", pattern: /(契約|NDA|秘密保持|見積|発注|登記|税務|社保|雇用|労務|請求書)/ },
  { label: "medical", pattern: /(病院|診断|薬|保険証|症状|検査|通院|処方|予約|医療)/ },
  { label: "family", pattern: /(妻|夫|子ども|子供|親|父|母|家族|保育園|学校|介護)/ },
  { label: "person-name-ja", pattern: /[一-龯々]{2,8}(さん|様|氏|先生|くん|ちゃん)/ },
  { label: "person-name-en", pattern: /\b[A-Z][a-z]+ [A-Z][a-z]+\b/ },
  { label: "chat-log", pattern: /(LINE|Slack|Beeper|DM|メール|返信|発言|会話|議事録|チャット)/i },
  { label: "crm", pattern: /(紹介|面談|商談|会った|連絡|関係性|フォローアップ|follow up|TODO|返信する)/i },
  { label: "shared-url", pattern: /https:\/\/(?:drive\.google\.com|docs\.google\.com|mail\.google\.com|notion\.so|slack\.com|app\.slack\.com)\//i },
];

export const classifyNote = (note) => {
  const searchable = `${note.title ?? ""}\n${note.plaintext ?? ""}`;
  const secretReasons = matchLabels(secretRules, searchable);
  const sensitiveReasons = matchLabels(sensitiveRules, searchable);
  const attachmentReasons = Number(note.attachmentCount ?? 0) > 0 ? ["attachment-unread"] : [];
  const blocked = [...secretReasons, ...attachmentReasons].length > 0;
  const project = blocked || sensitiveReasons.length > 0 ? TAKALOG_PROJECT : PRIVATE_PROJECT;
  const reasons = [...secretReasons, ...attachmentReasons, ...sensitiveReasons];

  return {
    ...note,
    classification: {
      project,
      blocked,
      reasons: reasons.length > 0 ? reasons : ["default-private"],
    },
  };
};

export const noteHash = (note) =>
  sha256([note.id ?? "", note.modified ?? "", note.title ?? "", note.plaintext ?? ""].join("\n"));

export const renderBody = (classified) => {
  const note = classified;
  const classification = note.classification;
  const hash = noteHash(note);
  const header = [
    "from: Apple Notes",
    `source-account: ${note.account ?? ""}`,
    `source-folder: ${note.folder ?? ""}`,
    `source-id: ${note.id ?? ""}`,
    `modified: ${note.modified ?? ""}`,
    `source-hash: ${hash}`,
    `route: ${classification.project}`,
    `classification: ${classification.reasons.join(", ")}`,
  ].join("\n");
  const body = classification.blocked
    ? "本文は自動転記しない。認証情報または未読添付が含まれる可能性があるため、Apple Notes 側で手動確認する。"
    : String(note.plaintext ?? "").trimEnd();

  return `${header}\n\n${body}\n`;
};

export const planWrite = (classified, options = {}) => ({
  project: classified.classification.project,
  title: pageTitle(classified, classified.classification, options["title-prefix"] ?? DEFAULT_TITLE_PREFIX),
  hash: noteHash(classified),
  blocked: classified.classification.blocked,
  reasons: classified.classification.reasons,
  body: renderBody(classified),
});

const safeJsonParse = (text) => {
  try {
    return { ok: true, value: JSON.parse(text) };
  } catch (error) {
    return { ok: false, error };
  }
};

const lines = (text) =>
  text.split(/\r?\n/).map((line) => line.trim()).filter((line) => line.length > 0);

const parseJsonLines = (text) =>
  lines(text).map((line) => safeJsonParse(line)).reduce(
    (state, result) =>
      result.ok
        ? { ...state, values: [...state.values, result.value] }
        : { ...state, errors: [...state.errors, result.error.message] },
    { values: [], errors: [] },
  );

const jsonl = (values) => `${values.map((value) => JSON.stringify(value)).join("\n")}\n`;
const writeStdout = (text) => process.stdout.write(text);
const writeStderr = (text) => process.stderr.write(text);
const fail = (message, code = 1) => (writeStderr(`${message}\n`), process.exit(code));

const jxaExportScript = ({ account, folder, limit }) => `
const notes = Application("Notes");
const accountName = ${JSON.stringify(account)};
const folderName = ${JSON.stringify(folder)};
const limit = ${JSON.stringify(Number(limit ?? 0))};
const bounded = (items) => limit > 0 ? items.slice(0, limit) : items;
const accounts = notes.accounts().filter((account) => account.name() === accountName);
const folders = accounts.flatMap((account) =>
  account.folders()
    .filter((folder) => folder.name() === folderName)
    .map((folder) => ({ account: account.name(), folder: folder.name(), notes: folder.notes() }))
);
JSON.stringify({
  ok: folders.length > 0,
  account: accountName,
  folder: folderName,
  notes: folders.flatMap((entry) =>
    bounded(entry.notes).map((note) => ({
      account: entry.account,
      folder: entry.folder,
      id: String(note.id()),
      title: String(note.name()),
      modified: String(note.modificationDate()),
      plaintext: String(note.plaintext()),
      attachmentCount: note.attachments().length
    }))
  )
});
`;

const runExport = (options) => {
  const account = options.account ?? DEFAULT_ACCOUNT;
  const folder = options.folder ?? DEFAULT_FOLDER;
  const result = spawnSync(
    "osascript",
    ["-l", "JavaScript"],
    { input: jxaExportScript({ account, folder, limit: options.limit }), encoding: "utf8", maxBuffer: 128 * 1024 * 1024 },
  );
  const parsed = result.status === 0 ? safeJsonParse(result.stdout) : { ok: false, error: new Error(result.stderr || "osascript failed") };

  return parsed.ok
    ? (parsed.value.ok
      ? writeStdout(jsonl(parsed.value.notes))
      : (writeStderr(`apple-notes-to-scrapbox: folder not found: ${account}/${folder}\n`), writeStdout("")))
    : fail(`apple-notes-to-scrapbox export: ${parsed.error.message}`);
};

const runClassify = () => {
  const parsed = parseJsonLines(readFileSync(0, "utf8"));
  return parsed.errors.length > 0
    ? fail(`apple-notes-to-scrapbox classify: invalid JSONL: ${parsed.errors.join("; ")}`)
    : writeStdout(jsonl(parsed.values.map(classifyNote)));
};

const commandResult = (name, args, input = "") => {
  const result = spawnSync(name, args, { input, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  return result.status === 0
    ? { ok: true, stdout: result.stdout, stderr: result.stderr }
    : { ok: false, stdout: result.stdout, stderr: result.stderr, code: result.status };
};

const verifyWrite = (plan) => {
  const result = commandResult("cosense-fetch", ["-r", plan.title, "-p", plan.project]);
  return result.ok && result.stdout.includes(`source-hash: ${plan.hash}`)
    ? { ok: true, title: plan.title, project: plan.project }
    : { ok: false, title: plan.title, project: plan.project, error: result.stderr || "source-hash missing after write" };
};

const writeOne = (options) => (classified) => {
  const plan = planWrite(classified, options);
  const dry = options["dry-run"] === true;
  const write = dry
    ? { ok: true, stdout: "", stderr: "" }
    : commandResult(
      "scrapbox-write",
      ["--project", plan.project, "--title", plan.title, "--mode", "replace", "--verbatim"],
      plan.body,
    );
  const verified = dry ? { ok: true, title: plan.title, project: plan.project } : write.ok ? verifyWrite(plan) : { ok: false, error: write.stderr || "scrapbox-write failed" };

  return {
    ok: write.ok && verified.ok,
    dryRun: dry,
    project: plan.project,
    title: plan.title,
    url: `https://scrapbox.io/${plan.project}/${encodeURIComponent(plan.title.replace(/ /g, "_"))}`,
    hash: plan.hash,
    blocked: plan.blocked,
    reasons: plan.reasons,
    error: verified.ok ? undefined : verified.error,
  };
};

const runWrite = (options) => {
  const parsed = parseJsonLines(readFileSync(0, "utf8"));
  const results = parsed.values.map(writeOne(options));
  const failed = [...parsed.errors.map((error) => ({ ok: false, error })), ...results.filter((result) => !result.ok)];

  return failed.length > 0
    ? (writeStdout(jsonl(results)), fail(`apple-notes-to-scrapbox write: ${failed.map((f) => f.error).join("; ")}`))
    : writeStdout(jsonl(results));
};

const exportText = (options) => {
  const account = options.account ?? DEFAULT_ACCOUNT;
  const folder = options.folder ?? DEFAULT_FOLDER;
  const result = spawnSync(
    "osascript",
    ["-l", "JavaScript"],
    { input: jxaExportScript({ account, folder, limit: options.limit }), encoding: "utf8", maxBuffer: 128 * 1024 * 1024 },
  );
  const parsed = result.status === 0 ? safeJsonParse(result.stdout) : { ok: false, error: new Error(result.stderr || "osascript failed") };

  return parsed.ok
    ? (parsed.value.ok
      ? jsonl(parsed.value.notes)
      : (writeStderr(`apple-notes-to-scrapbox: folder not found: ${account}/${folder}\n`), ""))
    : fail(`apple-notes-to-scrapbox sync/export: ${parsed.error.message}`);
};

const runSync = (options) => {
  const notes = parseJsonLines(exportText(options)).values;
  const classified = notes.map(classifyNote);
  const results = classified.map(writeOne(options));
  const failed = results.filter((result) => !result.ok);

  return failed.length > 0
    ? (writeStdout(jsonl(results)), fail(`apple-notes-to-scrapbox sync: ${failed.map((f) => f.error).join("; ")}`))
    : writeStdout(jsonl(results));
};

const help = () => `Usage:
  apple-notes-to-scrapbox export [--account iCloud] [--folder "Scrapbox Sync"] [--limit N]
  apple-notes-to-scrapbox classify < notes.jsonl
  apple-notes-to-scrapbox write [--dry-run] < classified.jsonl
  apple-notes-to-scrapbox sync [--dry-run] [--account iCloud] [--folder "Scrapbox Sync"]
`;

const commands = {
  export: runExport,
  classify: runClassify,
  write: runWrite,
  sync: runSync,
  help: () => writeStdout(help()),
};

const invokedAsScript = () => {
  try {
    return !!process.argv[1] && realpathSync(process.argv[1]) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
};

const main = () => {
  const command = process.argv[2] ?? "help";
  const options = parseOptions(process.argv.slice(3));
  const action = commands[command] ?? commands.help;
  return action(options);
};

invokedAsScript() ? main() : undefined;
