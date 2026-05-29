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
const bodyToLines = (title, body) => [title, ...body.split("\n").map(indentBodyLine)];
const lineText = (line) => typeof line === "string" ? line : line.text;
const withBlankSeparator = (lines) =>
  lines.length <= 1 || isBlankLine(lines.at(-1) ?? "")
    ? lines
    : [...lines, ""];

const patchStrategies = {
  replace: (title, body) => () => bodyToLines(title, body),
  // append: old body → blank → new body (newest at the end).
  append: (title, body) => (currentLines) => {
    const existingLines = currentLines.map(lineText);
    const newBody = bodyToLines(title, body).slice(1);
    return existingLines.length === 0
      ? bodyToLines(title, body)
      : [...withBlankSeparator(existingLines), ...newBody];
  },
  // prepend: title → new body → blank → old body (newest at the top, per 逆時系列 convention).
  prepend: (title, body) => (currentLines) => {
    const existingLines = currentLines.map(lineText);
    const newBody = bodyToLines(title, body).slice(1);
    return existingLines.length === 0
      ? bodyToLines(title, body)
      : [existingLines[0], ...withBlankSeparator(newBody), ...existingLines.slice(1)];
  },
};

const renderDryRun = (title, body) =>
  process.stdout.write(`${bodyToLines(title, body).join("\n")}\n`);

const patchPage = (project, title, patchStrategy, sid) =>
  import("@cosense/std/websocket")
    .then(({ patch }) => patch(project, title, patchStrategy, { sid }));

const writePage = (args, body, patchStrategy) =>
  args.dryRun
    ? Promise.resolve(renderDryRun(args.title, body))
    : patchPage(args.project, args.title, patchStrategy(args.title, body), process.env.SCRAPBOX_SID)
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

main().catch((error) => die(formatUnknownError(error)));
