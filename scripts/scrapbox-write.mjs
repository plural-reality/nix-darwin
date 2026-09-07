#!/usr/bin/env node
// scrapbox-write: Hermetic Scrapbox page writer via @cosense/std WebSocket patch.
// Reads page body from stdin, writes to Scrapbox.
//
// Usage:
//   echo "line1\nline2" | scrapbox-write --project tkgshn-private --title "Page Title"
//   scrapbox-write -p plural-reality -t "Meeting Notes" < body.txt
//   echo "follow-up" | scrapbox-write --mode append --title "Meeting Notes"
//   echo "newest note" | scrapbox-write --prepend --title "Meeting Notes"
//   scrapbox-write --dry-run --title "Preview" < body.txt
//   scrapbox-write --verbatim --title "Page" < exact-body.txt   # byte-for-byte, no indent injection
//
// Environment:
//   SCRAPBOX_SID — connect.sid cookie value (URL-decoded, starts with "s:")

import { createHash } from "node:crypto";
import { normalizeStatusEmoji } from "./scrapbox-title-normalize.mjs";

const usage = `Usage:
  scrapbox-write --title "Page Title" [--project plural-reality] [--mode replace|append|prepend] [--dry-run]
  scrapbox-write -t "Meeting Notes" -p plural-reality --append < body.txt

Modes:
  replace  Replace the full page body with stdin content (default)
  append   Append stdin content to the end of the existing page body
  prepend  Insert stdin content at the top of the page, right after the title

Options:
  -p, --project <name>  Scrapbox project name (default: plural-reality)
  -t, --title <title>   Scrapbox page title
  -a, --append          Alias for --mode append
  -P, --prepend         Alias for --mode prepend
  -V, --verbatim        Write body lines byte-for-byte (no indent injection / blank
                        collapse). For in-place rewrites preserving exact indentation,
                        human lines, and code: blocks. stdin omits the title line.
                        (Disables grey marking — caller controls exact bytes.)
  -g, --gray            Wrap AI-written lines in the [( …] grey deco (default ON for
                        non-verbatim writes; idempotent; skips code:/table: blocks).
      --no-gray, --human  Write plain (un-greyed). For human-authored content.
      --expect-page-id <id> Require this persisted page ID and the exact requested
                           title. Rechecked after a concurrent-edit retry.
      --expect-sha256 <h> Replace only when the current canonical line array has this
                          SHA-256. Concurrent edits abort instead of being overwritten.
  -n, --dry-run         Render Scrapbox lines to stdout without writing
  -h, --help            Show this help
`;

const die = (msg) => { process.stderr.write(`scrapbox-write: ${msg}\n`); process.exit(1); };
const showHelp = () => process.stdout.write(`${usage}\n`);

const optionValue = (argv, index) => argv[index + 1];
const isMissingOptionValue = (argv, index) =>
  optionValue(argv, index) === undefined || optionValue(argv, index).startsWith("-");
const formatUnknownError = (error) =>
  error instanceof Error ? error.message : JSON.stringify(error);

const optionsWithValue = {
  "--project": "project",
  "-p": "project",
  "--title": "title",
  "-t": "title",
  "--mode": "mode",
  "--expect-sha256": "expectSha256",
  "--expect-page-id": "expectPageId",
};

const flagOptions = {
  "--append": { mode: "append" },
  "-a": { mode: "append" },
  "--prepend": { mode: "prepend" },
  "-P": { mode: "prepend" },
  "--verbatim": { verbatim: true },
  "-V": { verbatim: true },
  "--gray": { gray: true },
  "-g": { gray: true },
  "--no-gray": { gray: false },
  "--human": { gray: false },
  "--dry-run": { dryRun: true },
  "-n": { dryRun: true },
  "--help": { help: true },
  "-h": { help: true },
};

const parseArgs = (argv) =>
  argv.slice(2).reduce(
    (acc, arg, i, arr) =>
      optionsWithValue[arg] !== undefined
        ? { ...acc, [optionsWithValue[arg]]: optionValue(arr, i) }
      : flagOptions[arg] !== undefined
        ? { ...acc, ...flagOptions[arg] }
      : arg.startsWith("-")
        ? { ...acc, unknownOptions: [...acc.unknownOptions, arg] }
      : acc,
    {
      project: "plural-reality",
      title: undefined,
      mode: "replace",
      help: false,
      dryRun: false,
      verbatim: false,
      gray: undefined,
      expectSha256: undefined,
      expectPageId: undefined,
      unknownOptions: [],
    }
  );

const validateArgs = (argv, args, patchStrategy) => {
  const missingValueOption = argv
    .slice(2)
    .find((arg, index, rest) => optionsWithValue[arg] !== undefined && isMissingOptionValue(rest, index));

  return args.help
    ? { ok: true, value: args }
  : missingValueOption !== undefined
    ? { ok: false, error: `${missingValueOption} requires a value` }
  : args.unknownOptions.length > 0
    ? { ok: false, error: `unknown option: ${args.unknownOptions.join(", ")}` }
  : !process.env.SCRAPBOX_SID && !args.dryRun
    ? { ok: false, error: "SCRAPBOX_SID environment variable is not set" }
  : args.expectPageId !== undefined && !/^[0-9a-f]{24}$/.test(args.expectPageId)
    ? { ok: false, error: "--expect-page-id requires 24 lowercase hexadecimal characters" }
  : args.expectSha256 !== undefined && !/^[0-9a-f]{64}$/.test(args.expectSha256)
    ? { ok: false, error: "--expect-sha256 requires 64 lowercase hexadecimal characters" }
  : !args.title || args.title.trim() === ""
    ? { ok: false, error: "--title (-t) is required" }
  : args.expectPageId !== undefined && args.title !== args.title.trim()
    ? { ok: false, error: "--expect-page-id requires --title without leading or trailing whitespace" }
  : !patchStrategy
    ? { ok: false, error: `unsupported mode: ${args.mode}` }
  : { ok: true, value: { ...args, title: args.title.trim(), project: args.project.trim() } };
};

const validateBody = (body) =>
  body.trim() === ""
    ? { ok: false, error: "stdin body is empty" }
    : { ok: true, value: body.replace(/\r\n?/g, "\n").replace(/\n$/, "") };

const foldResult = (result, handlers) =>
  result.ok
    ? handlers.ok(result.value)
    : handlers.error(result.error);

const readStdin = () =>
  new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    process.stdin.on("error", reject);
  });

const isBlankLine = (line) => line.trim() === "";
// Blank lines must stay truly empty: Scrapbox renders a space-only line as a stray
// empty bullet (every body line is indented one level), so collapse blanks to "".
const indentBodyLine = (line) => isBlankLine(line) ? "" : ` ${line}`;

// --- LLM grey marking (scrapbox-llm-marking). On by default for new content so
// AI-written text is visually faint (`[( …]`, opacity 0.5 via UserCSS) until a human
// approves it; the recurring failure was agents writing un-marked prose. Canonical
// line logic mirrors daily-page.py mark_gray + the llm-auto-humanize grayify.
// Off under --verbatim (caller controls exact bytes / mixed human lines) and --no-gray.
const isCodeSpan = (seg) => /^`[^`]+`$/.test(seg);
// Canonical deco parsing, ported byte-faithfully from the single source of truth for the
// [( … ] grey contract (tkgshn-extension/llm-auto-humanize `gray`/`leadingDeco`). matchClose
// finds the ']' matching a leading '[' by bracket depth, so nested links ([( [x]]) and
// trailing provenance are not mis-cut; leadingDeco parses a leading decoration token
// [<chars> <content>] (chars ∈ ( * / - _), returning null for a plain link [Page] whose
// first word is not decoration chars.
const matchClose = (s) => {
  const step = (depth, i) =>
    i >= s.length ? -1
    : s[i] === "[" ? step(depth + 1, i + 1)
    : s[i] === "]" ? (depth === 1 ? i : step(depth - 1, i + 1))
    : step(depth, i + 1);
  return step(0, 0);
};
const DECO = /^[(*\/_-]+$/;
const leadingDeco = (core) => {
  const close = core[0] === "[" ? matchClose(core) : -1;
  const inner = close < 0 ? "" : core.slice(1, close);
  const sp = inner.indexOf(" ");
  const chars = sp < 0 ? "" : inner.slice(0, sp);
  return sp < 0 || !DECO.test(chars)
    ? null
    : { chars, content: inner.slice(sp + 1), rest: core.slice(close + 1) };
};
// Grey one core, mirroring canonical gray(): MERGE '(' into an existing leading decoration
// ([* X] → [(* X]) instead of nesting it ([( [* X]]); plain text → [( X]; a core whose
// leading deco already carries '(' is left unchanged (idempotent — round-trip with the
// approve UI's humanize is invariant). Greying decorated lines too is intended: the whole
// AI body stays faint until a human approves it.
const grayCore = (core) => {
  const d = leadingDeco(core);
  return core === "" || (d && d.chars.includes("(")) ? core
    : d ? `[(${d.chars} ${d.content}]${d.rest}`
    : `[( ${core}]`;
};
// A plain run (no code; bare links [Page] DO render inside a deco so they stay here) wraps
// as [( run], keeping leading/trailing space OUTSIDE so adjacent siblings read cleanly.
const grayPlainRun = (t) => {
  const [, lead, core, trail] = /^(\s*)([\s\S]*?)(\s*)$/.exec(t);
  return core === "" ? t : `${lead}[( ${core}]${trail}`;
};
// Grey a code-span-free segment by WALKING it so a decoration token ([* X], [/ y] …) found
// ANYWHERE — not just at the start (the old grayCore only handled a LEADING deco) — becomes
// a sibling [(* X] with '(' merged into the deco chars, never nested inside [( … ]. Scrapbox
// does not render a decoration that sits inside a deco bracket (same reason code spans are
// kept outside), so a mid-line [* bold] wrapped as [( … [* bold] … ] silently loses its
// bold; emitting [(* bold] as a sibling keeps BOTH gray (deco-`(`) and bold (deco-`*`).
// Inverse-stable with canonical ungray, which melts sibling [(* X] → [* X] and
// [( a][(* X][( b] → a[* X]b, so humanize(grayify(x)) === x still holds.
const grayInline = (seg) => {
  const walk = (rest, plain) => {
    const open = rest.indexOf("[");
    const close = open < 0 ? -1 : matchClose(rest.slice(open));
    if (close < 0) return grayPlainRun(plain + rest);
    const token = rest.slice(open, open + close + 1);
    const after = rest.slice(open + close + 1);
    const d = leadingDeco(token);
    return d === null
      ? walk(after, plain + rest.slice(0, open) + token)
      : grayPlainRun(plain + rest.slice(0, open)) +
        (d.chars.includes("(") ? token : `[(${d.chars} ${d.content}]`) +
        walk(after, "");
  };
  return walk(seg, "");
};
// Backtick code spans stay OUTSIDE the deco (they don't render monospace inside it); every
// other segment is walked by grayInline so mid-line decorations survive as siblings.
const markGrayText = (text) =>
  text
    .split(/(`[^`]+`)/)
    .map((seg) => (isCodeSpan(seg) ? seg : grayInline(seg)))
    .join("");
const indentLen = (line) => /^(\s*)/.exec(line)[1].length;
const isStructuralHeader = (line) => /^\s*(code:|table:)\S/.test(line);

const GTD_BOARD_LINKS = Object.freeze({
  "ToDoカンバン": "[プロジェクト看板]",
  "プロジェクト看板": "[ToDoカンバン]",
});
const boardLink = (args) =>
  args.project === "plural-reality" && Object.hasOwn(GTD_BOARD_LINKS, args.title)
    ? GTD_BOARD_LINKS[args.title]
    : undefined;
const linesOutsideStructuralBlocks = (body) =>
  body.split("\n").reduce(
    (acc, line) => {
      const blank = isBlankLine(line);
      const inBlock = acc.block !== null && (blank || indentLen(line) > acc.block);
      const block = inBlock ? acc.block : isStructuralHeader(line) ? indentLen(line) : null;
      return { lines: inBlock ? acc.lines : [...acc.lines, line], block };
    },
    { lines: [], block: null },
  ).lines;
const bodyHasExactLine = (body, expected) =>
  linesOutsideStructuralBlocks(body).some((line) => line.trim() === expected);
const WIP_MARKER = "[claude code WIP.icon]";
const isQueueHeading = (line) => /^\[\*+\s+(?:todo|wip|done)\]$/u.test(line.trim());
const isQueueTask = (line) =>
  /^(?:\[\(\s*)?\[(?:⬜|⏳|⏹️|🚨|☑️|⌛️|✅)[^\]\n]+\](?:\])?$/u.test(line.trim());
const isAllowedWipQueueLine = (line) =>
  isBlankLine(line) || isQueueHeading(line) || isQueueTask(line);
const hasStandaloneAgentProgress = (body) =>
  body.split("\n").reduce(
    (acc, line) => {
      const marker = line.includes(WIP_MARKER);
      const exactMarker = line.trim() === WIP_MARKER;
      const insideQueue =
        acc.wipIndent !== null && (isBlankLine(line) || indentLen(line) > acc.wipIndent);
      const forbidden =
        acc.forbidden ||
        /\[(?:codex|claude code)\.icon\]/u.test(line) ||
        (marker && !exactMarker) ||
        (insideQueue && !isAllowedWipQueueLine(line));
      const wipIndent = exactMarker
        ? indentLen(line)
        : insideQueue
          ? acc.wipIndent
          : null;
      return { forbidden, wipIndent };
    },
    { forbidden: false, wipIndent: null },
  ).forbidden;

// A GTD board is a curated index, not a log sink. Full replacement is the only write
// boundary because it lets the caller prove the exact before/after line arrays.
const validateBoardWrite = (args, body) =>
  boardLink(args) === undefined
    ? { ok: true, value: body }
  : args.mode !== "replace"
    ? { ok: false, error: "GTD boards reject append/prepend; use a full replace" }
  : !args.verbatim
    ? { ok: false, error: "GTD boards require --verbatim to preserve the exact index" }
  : args.expectSha256 === undefined
    ? { ok: false, error: "GTD boards require --expect-sha256 for concurrent-edit protection" }
  : !bodyHasExactLine(body, boardLink(args))
    ? { ok: false, error: `GTD board requires reciprocal link ${boardLink(args)}` }
  : hasStandaloneAgentProgress(body)
    ? { ok: false, error: "GTD boards reject standalone Codex/Claude progress blocks" }
  : { ok: true, value: body };

// Idempotent: a line whose LEADING decoration already carries '(' is already grey and is
// left alone (protects page objects like `[( [⬜ task]]` from double-wrapping). Uses the
// deco parser, not a substring scan — the old line.includes("[(") false-positived on prose
// that merely *mentions* the marker (docs about [( … ]), wrongly skipping it.
const isAlreadyGray = (line) => {
  const d = leadingDeco(line.replace(/^\s*/, ""));
  return !!(d && d.chars.includes("("));
};
// Grey every non-blank, not-yet-grey line, but skip code:/table: blocks entirely
// (header + indented children) so structure/tables and verbatim code survive.
const grayBodyLines = (lines) =>
  lines.reduce(
    (acc, line) => {
      const blank = isBlankLine(line);
      const inBlock = acc.block !== null && (blank || indentLen(line) > acc.block);
      if (inBlock) return { out: [...acc.out, line], block: acc.block };
      const block = isStructuralHeader(line) ? indentLen(line) : null;
      const keep = blank || block !== null || isAlreadyGray(line);
      return { out: [...acc.out, keep ? line : markGrayText(line)], block };
    },
    { out: [], block: null },
  ).out;

// Verbatim mode writes each body line byte-for-byte (no indent injection, no blank
// collapse). Use it for in-place rewrites where exact indentation, human-authored
// lines, and code: blocks must survive unchanged. stdin carries the body *without*
// the title line; --title is still prepended as line 0.
const bodyToLines = (title, body, verbatim, gray) => {
  const rawLines = body.split("\n");
  const grayed = gray ? grayBodyLines(rawLines) : rawLines;
  return [title, ...grayed.map(verbatim ? (line) => line : indentBodyLine)];
};
const lineText = (line) => typeof line === "string" ? line : line.text;
const linesDigest = (lines) =>
  createHash("sha256").update(JSON.stringify(lines)).digest("hex");
// @cosense/std supplies the actual pulled Page as the callback's second argument.
// Keep identity checks inside this callback: NotFastForward retries pull by title,
// so a renamed/deleted page can otherwise resolve to a different (or phantom) page.
const patchPreconditionError = (title, expected, expectedPageId, current, page) =>
  expectedPageId !== undefined && (page?.persistent !== true || page?.id !== expectedPageId)
    ? "target page ID mismatch or page is not persisted; write aborted"
  : expectedPageId !== undefined && (page?.title !== title || current[0] !== title)
    ? "target page title mismatch; write aborted"
  : expected !== undefined && linesDigest(current) !== expected
    ? "concurrent edit detected; write aborted"
    : undefined;

const guardPatchStrategy = (title, expected, strategy, expectedPageId) => (currentLines, page) => {
  const current = currentLines.length === 0 ? [title] : currentLines.map(lineText);
  const error = patchPreconditionError(title, expected, expectedPageId, current, page);
  // The upstream patch callback uses exceptions to abort without committing.
  return error === undefined
    ? strategy(currentLines)
    : (() => { throw new Error(error); })();
};
const withBlankSeparator = (lines) =>
  lines.length <= 1 || isBlankLine(lines.at(-1) ?? "")
    ? lines
    : [...lines, ""];

const patchStrategies = {
  replace: (title, body, verbatim, gray) => () => bodyToLines(title, body, verbatim, gray),
  // append: old body → blank → new body (newest at the end).
  append: (title, body, verbatim, gray) => (currentLines) => {
    const existingLines = currentLines.map(lineText);
    const newBody = bodyToLines(title, body, verbatim, gray).slice(1);
    return existingLines.length === 0
      ? bodyToLines(title, body, verbatim, gray)
      : [...withBlankSeparator(existingLines), ...newBody];
  },
  // prepend: title → new body → blank → old body (newest at the top, per 逆時系列 convention).
  prepend: (title, body, verbatim, gray) => (currentLines) => {
    const existingLines = currentLines.map(lineText);
    const newBody = bodyToLines(title, body, verbatim, gray).slice(1);
    return existingLines.length === 0
      ? bodyToLines(title, body, verbatim, gray)
      : [existingLines[0], ...withBlankSeparator(newBody), ...existingLines.slice(1)];
  },
};

const renderDryRun = (title, body, verbatim, gray) =>
  process.stdout.write(`${bodyToLines(title, body, verbatim, gray).join("\n")}\n`);

const patchPage = (project, title, patchStrategy, sid) =>
  import("@cosense/std/websocket")
    .then(({ patch }) => patch(project, title, patchStrategy, { sid }));

// Grey by default for new content; never under --verbatim (caller owns exact bytes),
// never when --no-gray is passed.
const effectiveGray = (args) => !args.verbatim && args.gray !== false;

// VS16 揺れタイトルでの二重ページ生成を入口で防ぐ。ただし「与えられた表記そのままの
// ページが実在する」場合はそちらを正とする(mid-page 編集フローが正確なタイトルで
// 既存ページを指名するのを、正規化で別ページへ逸らさないため)。
//
// 正規化先を選ぶのは「与えられた表記のページが不在」を **確認できた時だけ**:
//   200 + persistent:false → phantom(実体なし) → 正規形へ
//   404                    → 不在 → 正規形へ
//   それ以外(403/5xx/parse失敗/ネットワーク断) → 不在の証拠にならないので与えられた表記を維持
//   (SID 失効時の 403 で既存ページを正規形の別ページへ逸らすと、防ぐはずの二重化を自ら起こす)
export const decideWriteTitle = (title, norm, status, meta) =>
  status === 200
    ? (meta && meta.persistent !== false ? title : norm)
  : status === 404
    ? norm
    : title;

const resolveWriteTitle = (project, title, sid) => {
  const norm = normalizeStatusEmoji(title);
  return norm === title
    ? Promise.resolve(title)
    : fetch(
        `https://scrapbox.io/api/pages/${encodeURIComponent(project)}/${encodeURIComponent(title)}`,
        { headers: { Cookie: `connect.sid=${encodeURIComponent(sid)}` } },
      )
        .then((res) =>
          res.status === 200
            ? res.json().then((meta) => decideWriteTitle(title, norm, 200, meta), () => title)
            : decideWriteTitle(title, norm, res.status, null),
        )
        .catch(() => title); // 照会不能時は与えられた表記を維持(現状動作へ縮退)
};

const writePage = (args, body, patchStrategy) =>
  args.dryRun
    ? Promise.resolve(renderDryRun(args.expectPageId === undefined ? normalizeStatusEmoji(args.title) : args.title, body, args.verbatim, effectiveGray(args)))
    : (args.expectPageId === undefined
        ? resolveWriteTitle(args.project, args.title, process.env.SCRAPBOX_SID)
        : Promise.resolve(args.title)).then((title) =>
        patchPage(
          args.project,
          title,
          guardPatchStrategy(
            title,
            args.expectSha256,
            patchStrategy(title, body, args.verbatim, effectiveGray(args)),
            args.expectPageId,
          ),
          process.env.SCRAPBOX_SID,
        )
          .then((result) =>
            result.ok
              ? process.stdout.write(`https://scrapbox.io/${args.project}/${encodeURIComponent(title)}\n`)
              : die(`patch failed: ${JSON.stringify(result)}`)
          ));

const main = () => {
  const args = parseArgs(process.argv);
  const patchStrategy = patchStrategies[args.mode];
  const argsResult = validateArgs(process.argv, args, patchStrategy);

  return args.help
    ? Promise.resolve(showHelp())
    : foldResult(argsResult, {
      ok: (validArgs) =>
        readStdin()
          .then(validateBody)
          .then((bodyResult) =>
            foldResult(bodyResult, {
              ok: (body) =>
                foldResult(validateBoardWrite(validArgs, body), {
                  ok: (validBody) => writePage(validArgs, validBody, patchStrategy),
                  error: die,
                }),
              error: die,
            })
          ),
      error: die,
    });
};

// Run main only when invoked as the entry script; importing this module (tests, the grey
// migration filter) reuses the pure grey logic below WITHOUT triggering a write — keeping
// the [( … ] contract defined in exactly one place.
import { pathToFileURL } from "node:url";
const isEntry = import.meta.url === pathToFileURL(process.argv[1] ?? "").href;
isEntry && main().catch((error) => die(formatUnknownError(error)));

// Pure grey-marking logic, exported for unit tests and one-off in-place re-marking.
export {
  grayBodyLines,
  grayCore,
  guardPatchStrategy,
  isAlreadyGray,
  leadingDeco,
  linesDigest,
  markGrayText,
  matchClose,
  validateBoardWrite,
};
