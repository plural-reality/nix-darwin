import { spawn } from "node:child_process";
import { close, open, read, stat } from "node:fs";
import { basename } from "node:path";

type HookPayload = Readonly<{
  cwd?: string;
  session_id?: string;
  transcript_path?: string;
  stop_hook_active?: boolean;
}>;

type ClaudeContentBlock = Readonly<{
  type?: string;
  text?: string;
}>;

type ClaudeTranscriptLine = Readonly<{
  type?: string;
  message?: Readonly<{
    content?: string | ReadonlyArray<ClaudeContentBlock>;
    stop_reason?: string | null;
  }>;
  cwd?: string;
  sessionId?: string;
}>;

type Result<T> =
  | Readonly<{ ok: true; value: T }>
  | Readonly<{ ok: false; error: unknown }>;

const leakRe =
  /^[ \t]*<(?:[A-Za-z][\w.-]*:)?(?:invoke\s+name=|function_calls\s*>|parameter\s+name=)/m;

const tailBytes = 1024 * 1024;

const readStdin = (then: (input: string) => void): typeof process.stdin =>
  process.stdin
    .setEncoding("utf8")
    .on("data", (chunk) => chunks.push(String(chunk)))
    .on("end", () => then(chunks.join("")));

const chunks: string[] = [];

const safeJsonParse = <T>(text: string): Result<T> => {
  try {
    return { ok: true, value: JSON.parse(text) as T };
  } catch (error) {
    return { ok: false, error };
  }
};

const textFromContent = (
  content: ClaudeTranscriptLine["message"] extends Readonly<{ content?: infer T }>
    ? T
    : never,
): string =>
  typeof content === "string"
    ? content
    : Array.isArray(content)
      ? content
          .filter((block) => block.type === "text")
          .map((block) => block.text ?? "")
          .join("\n")
      : "";

const stripCodeFences = (text: string): string =>
  text
    .split("\n")
    .reduce(
      ({ lines, inFence }, line) =>
        line.trimStart().startsWith("```")
          ? { lines, inFence: !inFence }
          : inFence
            ? { lines, inFence }
            : { lines: [...lines, line], inFence },
      { lines: [] as ReadonlyArray<string>, inFence: false },
    )
    .lines.join("\n");

const lastAssistant = (transcript: string): ClaudeTranscriptLine | undefined =>
  transcript
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .map(safeJsonParse<ClaudeTranscriptLine>)
    .filter((result): result is Readonly<{ ok: true; value: ClaudeTranscriptLine }> => result.ok)
    .map((result) => result.value)
    .reverse()
    .find((line) => line.type === "assistant");

const isLeakedToolCall = (line: ClaudeTranscriptLine | undefined): boolean =>
  line === undefined
    ? false
    : leakRe.test(stripCodeFences(textFromContent(line.message?.content)));

const readTranscriptTail = (path: string, then: (text: string) => void): void =>
  stat(path, (statError, stats) =>
    statError
      ? then("")
      : open(path, "r", (openError, fd) =>
          openError
            ? then("")
            : ((length, position) => {
                const buffer = Buffer.alloc(length);
                read(fd, buffer, 0, length, position, (_readError, bytesRead) =>
                  close(fd, () => then(buffer.subarray(0, bytesRead).toString("utf8"))),
                );
              })(Math.min(stats.size, tailBytes), Math.max(0, stats.size - tailBytes)),
        ),
  );

const fishQuote = (value: string): string =>
  `'${value.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;

const handoffPrompt = ({
  cwd,
  sessionId,
  transcriptPath,
}: Readonly<{
  cwd: string;
  sessionId: string;
  transcriptPath: string;
}>): string =>
  [
    "Claude Code handoff: continue the interrupted local work.",
    `cwd: ${cwd}`,
    `Claude session_id: ${sessionId}`,
    `Claude transcript_path: ${transcriptPath}`,
    "First read the transcript tail from transcript_path and reconstruct the current task, commands already run, dirty-tree state, and the last intended action.",
    "The last Claude turn likely rendered a tool call as leaked XML text instead of executing it. Treat that XML as non-executed evidence only; do not assume the tool ran.",
    "Continue in the same working directory, preserve unrelated user changes, run the narrow verification that matches the task, and report concrete file/command outcomes.",
  ].join(" ");

const handoffCommand = ({
  cwd,
  sessionId,
  transcriptPath,
}: Readonly<{
  cwd: string;
  sessionId: string;
  transcriptPath: string;
}>): string =>
  [
    `cd ${fishQuote(cwd)};`,
    "and",
    "env",
    `CLAUDE_SESSION_ID=${fishQuote(sessionId)}`,
    `CLAUDE_TRANSCRIPT_PATH=${fishQuote(transcriptPath)}`,
    "codex",
    "--cd",
    fishQuote(cwd),
    fishQuote(handoffPrompt({ cwd, sessionId, transcriptPath })),
  ].join(" ");

const copyToClipboard = (text: string): void => {
  const process = spawn("/usr/bin/pbcopy", [], { stdio: ["pipe", "ignore", "ignore"] });
  process.stdin.end(text);
};

const notify = (cwd: string): void => {
  const process = spawn(
    "/usr/bin/osascript",
    [
      "-e",
      'display notification "Codex handoff command copied to clipboard" with title "Claude Code" subtitle "壊れた tool call を検知" sound name "Glass"',
    ],
    { stdio: "ignore" },
  );

  process.unref();
  void basename(cwd);
};

const run = (input: string): void => {
  const payload = safeJsonParse<HookPayload>(input);
  const value = payload.ok ? payload.value : undefined;
  const transcriptPath = value?.transcript_path ?? "";
  const cwd = value?.cwd ?? process.cwd();
  const sessionId = (value?.session_id ?? basename(transcriptPath, ".jsonl")) || "unknown";

  value?.stop_hook_active
    ? undefined
    : transcriptPath.length === 0
      ? undefined
      : readTranscriptTail(transcriptPath, (transcript) =>
          isLeakedToolCall(lastAssistant(transcript))
            ? (copyToClipboard(handoffCommand({ cwd, sessionId, transcriptPath })), notify(cwd))
            : undefined,
        );
};

readStdin(run);
