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
  : !args.title || args.title.trim() === ""
    ? { ok: false, error: "--title (-t) is required" }
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
// Backtick code spans stay OUTSIDE the deco (they don't render monospace inside it);
// each plain segment's core is greyed, leading/trailing space (incl. Scrapbox indent)
// kept outside so spacing/indent survive. Only the first plain segment can carry a
// leading decoration; later segments parse as plain and wrap as [( … ].
const markGrayText = (text) =>
  text
    .split(/(`[^`]+`)/)
    .map((seg) => {
      if (isCodeSpan(seg)) return seg;
      const [, lead, core, trail] = /^(\s*)([\s\S]*?)(\s*)$/.exec(seg);
      return core === "" ? seg : `${lead}${grayCore(core)}${trail}`;
    })
    .join("");
const indentLen = (line) => /^(\s*)/.exec(line)[1].length;
const isStructuralHeader = (line) => /^\s*(code:|table:)\S/.test(line);
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

const writePage = (args, body, patchStrategy) =>
  args.dryRun
    ? Promise.resolve(renderDryRun(args.title, body, args.verbatim, effectiveGray(args)))
    : patchPage(args.project, args.title, patchStrategy(args.title, body, args.verbatim, effectiveGray(args)), process.env.SCRAPBOX_SID)
      .then((result) =>
        result.ok
          ? process.stdout.write(`https://scrapbox.io/${args.project}/${encodeURIComponent(args.title)}\n`)
          : die(`patch failed: ${JSON.stringify(result)}`)
      );

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
              ok: (body) => writePage(validArgs, body, patchStrategy),
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
export { markGrayText, grayCore, grayBodyLines, leadingDeco, matchClose, isAlreadyGray };
