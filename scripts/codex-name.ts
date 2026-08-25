import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createInterface } from "node:readline";

type JsonPrimitive = string | number | boolean | null;
type JsonValue =
  | JsonPrimitive
  | ReadonlyArray<JsonValue>
  | { readonly [key: string]: JsonValue };
type Result<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: string };
type Args = Readonly<{
  threadId?: string;
  name?: string;
  all: boolean;
  auto: boolean;
  notify: boolean;
  noLlm: boolean;
  model: string;
}>;
type NotifyEvent = Readonly<{
  readonly threadId?: string;
  readonly lastAssistantMessage?: string;
}>;
type Thread = Readonly<{
  id: string;
  preview: string;
  name: string | null;
  cwd: string;
  path: string | null;
}>;
type Response = Readonly<{
  id?: string | number;
  method?: string;
  result?: JsonValue;
  error?: { readonly message?: string };
  params?: JsonValue;
}>;
type TitleStatus = "⬜" | "⌛️" | "☑️" | "⏹️" | "🚨";

const usage = `Usage:
  codex-name "New session name"
  codex-name --id <thread-id> "New session name"
  codex-name --auto
  codex-name --auto --model gpt-5.3-codex-spark
  codex-name --auto --no-llm
  codex-name --notify --auto
  codex-name --all --auto

Default target is the newest non-archived Codex thread for the current cwd.
Use --id when multiple Codex sessions are active.`;

const ok = <T>(value: T): Result<T> => ({ ok: true, value });
const err = <T = never>(error: string): Result<T> => ({ ok: false, error });
const messageOf = (error: unknown): string =>
  error instanceof Error ? error.message : String(error);
const tryResult = <T>(thunk: () => T): Result<T> => {
  try {
    return ok(thunk());
  } catch (error) {
    return err(messageOf(error));
  }
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === "object" && !Array.isArray(value);

const asResponse = (value: unknown): Result<Response> =>
  isRecord(value) ? ok(value as Response) : err("app-server emitted non-object JSON");

const parseJson = (line: string): Result<Response> =>
  ((parsed) => (parsed.ok ? asResponse(parsed.value) : err(parsed.error)))(
    tryResult(() => JSON.parse(line)),
  );

const isUuid = (value: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

const parseArgs = (argv: ReadonlyArray<string>): Result<Args> =>
  argv.includes("--help") || argv.includes("-h")
    ? err(usage)
    : ((idIndex) =>
        ((modelIndex) =>
          ((threadId) =>
            threadId && !isUuid(threadId)
              ? err(`invalid --id UUID: ${threadId}`)
              : ((auto) =>
                  ((name) =>
                    !auto && name.length === 0
                      ? err("missing session name; pass a name or --auto")
                      : ok({
                          threadId,
                          name: name.length > 0 ? name : undefined,
                          all: argv.includes("--all"),
                          auto,
                          notify: argv.includes("--notify"),
                          noLlm: argv.includes("--no-llm"),
                          model:
                            (modelIndex >= 0 ? argv[modelIndex + 1] : undefined) ??
                            process.env.CODEX_NAME_MODEL ??
                            "gpt-5.3-codex-spark",
                        }))(
                    argv
                      .filter(
                        (arg, index) =>
                          !["--id", "--all", "--auto", "--notify", "--no-llm", "--model"].includes(arg) &&
                          !(idIndex >= 0 && index === idIndex + 1) &&
                          !(modelIndex >= 0 && index === modelIndex + 1),
                      )
                      .join(" ")
                      .trim(),
                  ))(argv.includes("--auto")))(idIndex >= 0 ? argv[idIndex + 1] : undefined))(
            argv.findIndex((arg) => arg === "--model"),
          ))(
        argv.findIndex((arg) => arg === "--id"),
      );

const autoName = (preview: string): string =>
  preview
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/https?:\/\/\S+/g, " ")
    .replace(/[ \t\r\n]+/g, " ")
    .trim()
    .slice(0, 72) || "Codex session";

const statusOf = (title: string | null | undefined): TitleStatus | undefined =>
  /^⬜️?\s*/u.test(title ?? "")
    ? "⬜"
    : /^⌛️?\s*/u.test(title ?? "")
      ? "⌛️"
      : /^☑️?\s*/u.test(title ?? "")
        ? "☑️"
        : /^⏹️?\s*/u.test(title ?? "")
          ? "⏹️"
          : /^🚨\s*/u.test(title ?? "")
            ? "🚨"
            : undefined;

const topicOf = (title: string): string =>
  title
    .replace(/^(?:⬜️?|⌛️?|☑️?|⏹️?|⏳|🚨)\s*(?:cc:\s*)?/u, "")
    .trim();

const titled = (current: string | null, next: string): string =>
  `${statusOf(next) ?? statusOf(current) ?? "⌛️"} ${topicOf(next) || "Codex session"}`.slice(
    0,
    72,
  );

const inferredStatus = (message: string): TitleStatus | undefined =>
  /(要確認|確認してください|判断待ち|選択してください|承認待ち|認証待ち|パスワード|入力待ち|本人の操作|human action|user action|needs? (?:your|user)|blocked|waiting for (?:you|user)|requires? (?:your|user))/iu.test(
    message,
  )
    ? "🚨"
    : /(完了|実装しました|対応しました|検証済み|確認済み|読戻し|成功|解決しました|deployed|verified|completed|finished|done|resolved)/iu.test(
          message,
        )
      ? "☑️"
      : undefined;

const statusTitled = (
  current: string | null,
  next: string,
  message: string,
): string =>
  `${statusOf(next) ?? statusOf(current) ?? inferredStatus(message) ?? "⌛️"} ${topicOf(next) || "Codex session"}`.slice(
    0,
    72,
  );

const titleStatusSelfCheck = (): boolean =>
  (
    [
      [null, "調査", "⌛️ 調査"],
      ["☑️ 完了済み", "調査", "☑️ 調査"],
      ["🚨 本人の判断待ち", "調査", "🚨 調査"],
      ["⏳ 旧記法", "調査", "⌛️ 調査"],
      [null, "☑️ 結論", "☑️ 結論"],
    ] as const
  ).every(([current, next, expected]) => titled(current, next) === expected);

const statusInferenceSelfCheck = (): boolean =>
  statusTitled(null, "調査", "完了しました。検証済みです") === "☑️ 調査" &&
  statusTitled(null, "調査", "承認待ちです") === "🚨 調査" &&
  statusTitled("🚨 調査", "調査", "進行中") === "🚨 調査";

const notifyEvent = (value: unknown): NotifyEvent =>
  isRecord(value)
    ? {
        threadId:
          typeof value["thread-id"] === "string"
            ? value["thread-id"]
            : typeof value.thread_id === "string"
              ? value.thread_id
              : undefined,
        lastAssistantMessage:
          typeof value["last-assistant-message"] === "string"
            ? value["last-assistant-message"]
            : typeof value.last_assistant_message === "string"
              ? value.last_assistant_message
              : undefined,
      }
    : {};

const parseNotifyEvent = (raw: string): Result<NotifyEvent> =>
  ((parsed) =>
    parsed.ok ? ok(notifyEvent(parsed.value)) : err(parsed.error))(tryResult(() => JSON.parse(raw)));

const notifyArgument = (argv: ReadonlyArray<string>): string | undefined =>
  argv.at(-1)?.trim().startsWith("{") ? argv.at(-1) : undefined;

const readNotifyEvent = (argv: ReadonlyArray<string>): Result<NotifyEvent> =>
  ((argument) =>
    argument ? parseNotifyEvent(argument) : err("notify event argument is missing"))(notifyArgument(argv));

const notifyInputSelfCheck = (): boolean =>
  ((parsed) =>
    parsed.ok &&
    parsed.value.threadId === "00000000-0000-4000-8000-000000000000" &&
    parsed.value.lastAssistantMessage === "完了しました")(
    readNotifyEvent([
      "--notify",
      "--auto",
      '{"type":"agent-turn-complete","thread-id":"00000000-0000-4000-8000-000000000000","last-assistant-message":"完了しました"}',
    ]),
  );

const contentText = (value: unknown): string =>
  typeof value === "string"
    ? value
    : Array.isArray(value)
      ? value
          .flatMap((item) =>
            isRecord(item) && typeof item.text === "string" ? [item.text] : [],
          )
          .join("\n")
      : "";

const rolloutMessage = (value: unknown): ReadonlyArray<string> =>
  isRecord(value) &&
  value.type === "response_item" &&
  isRecord(value.payload) &&
  value.payload.type === "message" &&
  (value.payload.role === "user" || value.payload.role === "assistant")
    ? [`${value.payload.role}: ${contentText(value.payload.content)}`]
    : [];

const rolloutMessages = (path: string | null): string =>
  path
    ? ((read) =>
        read.ok
          ? read.value
              .split(/\r?\n/)
              .flatMap((line) =>
                ((parsed) => (parsed.ok ? rolloutMessage(parsed.value) : []))(
                  tryResult(() => JSON.parse(line)),
                ),
              )
              .map((message) => message.replace(/[ \t\r\n]+/g, " ").trim())
              .filter(Boolean)
              .slice(-24)
              .join("\n")
          : "")(tryResult(() => readFileSync(path, "utf8")))
    : "";

const titleContext = (thread: Thread): string =>
  [thread.preview, rolloutMessages(thread.path)]
    .map((text) => text.replace(/[ \t\r\n]+/g, " ").trim())
    .filter(Boolean)
    .join("\n")
    .slice(-8_000);

const titlePrompt = (thread: Thread): string => `Name this Codex CLI session.

Return exactly one short title and nothing else.
Rules:
- Use the user's language.
- Prefer 2-8 words, or 32 Japanese characters or fewer.
- No quotes, markdown, emoji, trailing punctuation, or generic "Codex session".
- Name the actual task, not the tooling used to name it.

Session excerpt:
${titleContext(thread)}`;

const cleanName = (raw: string, fallback: string): string =>
  ((name) => (name.length > 0 ? name.slice(0, 72) : fallback))(
    raw
      .replace(/```[\s\S]*?```/g, " ")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .find(Boolean)
      ?.replace(/^[`"'「『]+|[`"'」』。.!！?？:：]+$/g, "")
      .replace(/[ \t\r\n]+/g, " ")
      .trim() ?? "",
  );

const cleanup = (path: string): boolean => (
  tryResult(() => rmSync(path, { recursive: true, force: true })),
  true
);

const once = <T>(callback: (value: T) => boolean): ((value: T) => boolean) => {
  const state = { called: false };
  return (value: T): boolean =>
    state.called ? false : ((state.called = true), callback(value));
};

const generatedName = (
  args: Args,
  thread: Thread,
  fallback: string,
  statusMessage: string,
  callback: (name: string) => boolean,
): boolean =>
  args.noLlm
    ? callback(statusTitled(thread.name, fallback, statusMessage))
    : ((dir) =>
        ((outputPath) =>
          ((finish) =>
            ((child) => (
              child.on("error", () => finish(fallback)),
              child.on("exit", (code) =>
                ((read) =>
                  finish(
                    code === 0 && read.ok ? cleanName(read.value, fallback) : fallback,
                  ))(tryResult(() => readFileSync(outputPath, "utf8"))),
              ),
              true
            ))(
              spawn(
                "codex",
                [
                  "exec",
                  "--ephemeral",
                  "--ignore-user-config",
                  "--disable",
                  "hooks",
                  "--ignore-rules",
                  "--skip-git-repo-check",
                  "--sandbox",
                  "read-only",
                  "-m",
                  args.model,
                  "-c",
                  'model_reasoning_effort="low"',
                  "-c",
                  'model_verbosity="low"',
                  "-c",
                  "notify=[]",
                  "-o",
                  outputPath,
                  titlePrompt(thread),
                ],
                { cwd: thread.cwd || process.cwd(), stdio: ["ignore", "ignore", "ignore"] },
              ),
            ))(
            once((name: string) => (cleanup(dir), callback(statusTitled(thread.name, name, statusMessage)))),
          ))(join(dir, "title.txt")))(
        mkdtempSync(join(tmpdir(), "codex-name-")),
      );

const request = (id: number, method: string, params: JsonValue): JsonValue => ({
  id,
  method,
  params,
});

const initializeRequest = request(1, "initialize", {
  clientInfo: { name: "codex-name", title: null, version: "0" },
  capabilities: {
    experimentalApi: true,
    requestAttestation: false,
    optOutNotificationMethods: ["remoteControl/status/changed"],
  },
});

const listRequest = (args: Args): JsonValue =>
  request(2, "thread/list", {
    limit: 1,
    archived: false,
    useStateDbOnly: true,
    sortKey: "updated_at",
    sortDirection: "desc",
    ...(args.all ? {} : { cwd: process.cwd() }),
  });

const readRequest = (threadId: string): JsonValue =>
  request(3, "thread/read", { threadId, includeTurns: false });

const setNameRequest = (threadId: string, name: string): JsonValue =>
  request(4, "thread/name/set", { threadId, name });

const firstThread = (response: Response): Thread | undefined =>
  isRecord(response.result) &&
  Array.isArray(response.result.data) &&
  isRecord(response.result.data[0]) &&
  typeof response.result.data[0].id === "string"
    ? (response.result.data[0] as Thread)
    : undefined;

const readThread = (response: Response): Thread | undefined =>
  isRecord(response.result) &&
  isRecord(response.result.thread) &&
  typeof response.result.thread.id === "string"
    ? (response.result.thread as Thread)
    : undefined;

const updatedName = (
  response: Response,
): Readonly<{ readonly threadId: string; readonly name: string }> | undefined =>
  response.method === "thread/name/updated" &&
  isRecord(response.params) &&
  typeof response.params.threadId === "string" &&
  typeof response.params.threadName === "string"
    ? { threadId: response.params.threadId, name: response.params.threadName }
    : undefined;

const fail = (message: string): never => (
  console.error(`codex-name: ${message}`),
  process.exit(1)
);

const complete = (
  child: ReturnType<typeof spawn>,
  timer: NodeJS.Timeout,
  update: Readonly<{ readonly threadId: string; readonly name: string }>,
): boolean => (
  clearTimeout(timer),
  console.log(`${update.threadId}\t${update.name}`),
  child.stdin.end()
);

const run = (args: Args): boolean => {
  const event = args.notify
    ? ((read) =>
        read.ok ? read.value : fail(`invalid notify event: ${read.error}`))(readNotifyEvent(process.argv.slice(2)))
    : {};
  const targetThreadId = event.threadId ?? args.threadId;
  const statusMessage = event.lastAssistantMessage ?? "";
  const targetError = args.notify && !targetThreadId ? "notify event did not contain thread-id" : undefined;
  targetError ? fail(targetError) : undefined;
  const child = spawn("codex", ["app-server", "--stdio"], {
    stdio: ["pipe", "pipe", "pipe"],
  });
  const send = (payload: JsonValue): boolean =>
    child.stdin.write(`${JSON.stringify(payload)}\n`);
  const setThreadName = (thread: Thread): boolean =>
    args.auto
      ? generatedName(args, thread, autoName(titleContext(thread) || thread.preview), statusMessage, (name) =>
          send(setNameRequest(thread.id, name)),
        )
    : send(setNameRequest(thread.id, statusTitled(thread.name, args.name ?? "Codex session", statusMessage)));
  const timer = setTimeout(() => fail("timed out waiting for codex app-server"), 45_000);
  const lines = createInterface({ input: child.stdout });

  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => process.stderr.write(chunk));
  child.on("error", (error) => fail(messageOf(error)));
  child.on("exit", (code) =>
    code === 0 || process.exitCode === 0
      ? undefined
      : fail(`codex app-server exited with code ${String(code)}`),
  );
  lines.on("line", (line) =>
    ((parsed) =>
      parsed.ok
        ? parsed.value.error
          ? fail(parsed.value.error.message ?? "app-server returned an error")
          : parsed.value.id === 1
            ? targetThreadId
              ? args.auto
                ? send(readRequest(targetThreadId))
                : send(setNameRequest(targetThreadId, args.name ?? "Codex session"))
              : send(listRequest(args))
            : parsed.value.id === 2
              ? ((thread) =>
                  thread
                    ? setThreadName(thread)
                    : fail(
                        args.all
                          ? "no Codex threads found"
                          : `no Codex threads found for cwd: ${process.cwd()}`,
                      ))(firstThread(parsed.value))
              : parsed.value.id === 3
                ? ((thread) =>
                    thread ? setThreadName(thread) : fail("thread/read did not return a thread"))(
                    readThread(parsed.value),
                  )
                : updatedName(parsed.value)
                  ? complete(child, timer, updatedName(parsed.value))
                  : undefined
        : fail(parsed.error))(parseJson(line)),
  );
  return send(initializeRequest);
};

process.argv.includes("--self-check")
  ? titleStatusSelfCheck() && statusInferenceSelfCheck() && notifyInputSelfCheck()
    ? console.log("codex-name: ok")
    : fail("self-check failed")
  : ((args) =>
      args.ok
        ? run(args.value)
        : (console.error(args.error), process.exit(args.error === usage ? 0 : 2)))(
      parseArgs(process.argv.slice(2)),
    );
