import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { DatabaseSync } from "node:sqlite";

type Result<T> =
  | Readonly<{ ok: true; value: T }>
  | Readonly<{ ok: false; error: string }>;
type Status = "⬜" | "⌛️" | "☑️" | "⏹️" | "🚨" | "none";
type Thread = Readonly<{
  id: string;
  title: string;
  cwd: string;
  archived: boolean;
  createdAt: number;
  recencyAt: number;
  mode: string;
  status: Status;
  objective: string;
}>;
type FindingKind =
  | "duplicate_exact"
  | "duplicate_objective"
  | "human_wait_status"
  | "stale_working"
  | "archive_candidate"
  | "missing_status";
type Finding = Readonly<{
  kind: FindingKind;
  priority: number;
  ids: ReadonlyArray<string>;
  title: string;
  reason: string;
  suggestion: string;
}>;
type AuditOptions = Readonly<{
  now: number;
  duplicateWindowHours: number;
  staleHours: number;
  lookbackDays: number;
  limit: number;
}>;
type AuditReport = Readonly<{
  generatedAt: string;
  lookbackDays: number;
  inputCount: number;
  findingCount: number;
  shownCount: number;
  limit: number;
  findings: ReadonlyArray<Finding>;
}>;
type Args = Readonly<{
  current: boolean;
  format: "json" | "markdown";
  limit: number;
  staleHours: number;
  duplicateWindowHours: number;
  lookbackDays: number;
}>;

const ok = <T>(value: T): Result<T> => ({ ok: true, value });
const err = <T = never>(error: string): Result<T> => ({ ok: false, error });
const isRecord = (value: unknown): value is Readonly<Record<string, unknown>> =>
  !!value && typeof value === "object" && !Array.isArray(value);
const asText = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim().length > 0 ? value : undefined;
const asNumber = (value: unknown): number | undefined =>
  typeof value === "number" && Number.isFinite(value) ? value : undefined;
const asBoolean = (value: unknown): boolean | undefined =>
  typeof value === "boolean" ? value : typeof value === "number" ? value !== 0 : undefined;

const statusOf = (title: string): Status =>
  /^⬜️?\s*/u.test(title)
    ? "⬜"
    : /^⌛️?\s*/u.test(title)
      ? "⌛️"
      : /^☑️?\s*/u.test(title)
        ? "☑️"
        : /^⏹️?\s*/u.test(title)
          ? "⏹️"
          : /^🚨\s*/u.test(title)
            ? "🚨"
            : "none";

export const normalizeObjective = (title: string): string =>
  title
    .normalize("NFKC")
    .replace(/^(?:⬜️?|⌛️?|☑️?|⏹️?|⏳|🚨)\s*(?:cc:\s*)?/u, "")
    .toLocaleLowerCase("ja-JP")
    .replace(/[\p{P}\p{S}_]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim();

const decodeThread = (value: unknown, index: number): Result<Thread> =>
  !isRecord(value)
    ? err(`threads[${index}] must be an object`)
    : ((id, title, cwd, archived, createdAt, recencyAt, mode) =>
        !id
          ? err(`threads[${index}].id must be a non-empty string`)
          : !title
            ? err(`threads[${index}].title must be a non-empty string`)
            : !cwd
              ? err(`threads[${index}].cwd must be a non-empty string`)
              : archived === undefined
                ? err(`threads[${index}].archived must be a boolean`)
                : createdAt === undefined
                  ? err(`threads[${index}].createdAt must be a number`)
                  : recencyAt === undefined
                    ? err(`threads[${index}].recencyAt must be a number`)
                    : ok({
                        id,
                        title,
                        cwd,
                        archived,
                        createdAt,
                        recencyAt,
                        mode: mode ?? "general",
                        status: statusOf(title),
                        objective: normalizeObjective(title),
                      }))(
        asText(value.id),
        asText(value.title ?? value.name),
        asText(value.cwd),
        asBoolean(value.archived),
        asNumber(value.createdAt ?? value.created_at),
        asNumber(value.recencyAt ?? value.updatedAt ?? value.recency_at ?? value.updated_at),
        asText(value.mode ?? value.source),
      );

export const decodeThreads = (value: unknown): Result<ReadonlyArray<Thread>> =>
  !Array.isArray(value)
    ? err("input must be a JSON array")
    : ((decoded) =>
        ((failure) =>
          failure && !failure.ok
            ? failure
            : ok(decoded.flatMap((item) => (item.ok ? [item.value] : []))))(
          decoded.find((item) => !item.ok),
        ))(value.map(decodeThread));

const groupBy = <T>(
  values: ReadonlyArray<T>,
  keyOf: (value: T) => string,
): ReadonlyArray<ReadonlyArray<T>> =>
  Object.values(
    values.reduce<Readonly<Record<string, ReadonlyArray<T>>>>(
      (groups, value) => ({
        ...groups,
        [keyOf(value)]: [...(groups[keyOf(value)] ?? []), value],
      }),
      {},
    ),
  );
const ageHours = (now: number, then: number): number => Math.max(0, (now - then) / 3_600);
const isScheduled = ({ mode }: Thread): boolean => /scheduled|automation|cron|heartbeat/i.test(mode);
const isSynthetic = ({ title, objective, mode }: Thread): boolean =>
  /^(?:exec|review|subagent)$/i.test(mode) ||
  /^<command-name>/i.test(title) ||
  /^(?:echo hello|reply with exactly\b)/i.test(objective) ||
  /^[a-z0-9][a-z0-9._:/-]{2,63}$/i.test(objective);
const hasExternalWait = ({ title }: Thread): boolean => /(?:返信|応答)待ち/u.test(title);
const hasHumanWait = ({ title }: Thread): boolean =>
  /(?:本人|あなた|ユーザー).{0,12}(?:判断|認証|確認|操作|対応)待ち|(?:判断|認証|確認|操作)が必要/u.test(title);
const groupWindow = (threads: ReadonlyArray<Thread>): number =>
  Math.max(...threads.map(({ createdAt }) => createdAt)) -
  Math.min(...threads.map(({ createdAt }) => createdAt));
const duplicateFinding = (
  kind: "duplicate_exact" | "duplicate_objective",
  threads: ReadonlyArray<Thread>,
): Finding => ({
  kind,
  priority: kind === "duplicate_exact" ? 100 : 90,
  ids: threads.map(({ id }) => id),
  title: [...new Set(threads.map(({ title }) => title))].join(" / "),
  reason:
    kind === "duplicate_exact"
      ? `同じcwd・mode・正規化目的の未アーカイブタスクが${threads.length}件あります。`
      : `同じ正規化目的・modeの未アーカイブタスクが${threads.length}件あります。cwd違いなので要確認です。`,
  suggestion: "既存タスクの正本を確認し、同じ作業なら1件へ寄せる候補です。自動変更はしません。",
});
const duplicateFindings = (
  threads: ReadonlyArray<Thread>,
  duplicateWindowHours: number,
): ReadonlyArray<Finding> =>
  groupBy(
    threads.filter((thread) => !isScheduled(thread) && !isSynthetic(thread) && thread.objective.length > 0),
    ({ objective, mode }) => `${mode}\0${objective}`,
  ).flatMap((objectiveGroup) =>
    objectiveGroup.length < 2 || groupWindow(objectiveGroup) > duplicateWindowHours * 3_600
      ? []
      : ((cwdGroups) => [
          ...cwdGroups
            .filter((group) => group.length > 1)
            .map((group) => duplicateFinding("duplicate_exact", group)),
          ...(cwdGroups.length > 1 ? [duplicateFinding("duplicate_objective", objectiveGroup)] : []),
        ])(groupBy(objectiveGroup, ({ cwd }) => cwd)),
  );
const lifecycleFindings = (
  threads: ReadonlyArray<Thread>,
  now: number,
  staleHours: number,
): ReadonlyArray<Finding> =>
  threads.flatMap((thread): ReadonlyArray<Finding> =>
    thread.status === "⌛️" && hasHumanWait(thread)
      ? [{
          kind: "human_wait_status",
          priority: 80,
          ids: [thread.id],
          title: thread.title,
          reason: "タイトルは作業中ですが、本人の判断・認証・確認・操作待ちを示しています。",
          suggestion: "正本を確認し、進められない状態なら🚨への変更候補です。",
        }]
      : thread.status === "⌛️" && !hasExternalWait(thread) && ageHours(now, thread.recencyAt) >= staleHours
        ? [{
            kind: "stale_working",
            priority: 70,
            ids: [thread.id],
            title: thread.title,
            reason: `最終活動から${Math.floor(ageHours(now, thread.recencyAt))}時間以上経過した⌛️です。`,
            suggestion: "正本を読み、継続・🚨・☑️・⏹️のどれかを判断する候補です。",
          }]
        : thread.status === "☑️" || thread.status === "⏹️"
          ? [{
              kind: "archive_candidate",
              priority: 40,
              ids: [thread.id],
              title: thread.title,
              reason: `${thread.status}の未アーカイブタスクです。`,
              suggestion: "正本と完了根拠を確認後にアーカイブする候補です。",
            }]
          : thread.status === "none"
            ? [{
                kind: "missing_status",
                priority: 20,
                ids: [thread.id],
                title: thread.title,
                reason: "状態prefixのない未アーカイブタスクです。",
                suggestion: "正本を確認して状態を付ける候補です。",
              }]
            : [],
  );

export const auditThreads = (
  threads: ReadonlyArray<Thread>,
  options: AuditOptions,
): AuditReport =>
  ((active) =>
    ((findings) => ({
      generatedAt: new Date(options.now * 1_000).toISOString(),
      lookbackDays: options.lookbackDays,
      inputCount: active.length,
      findingCount: findings.length,
      shownCount: Math.min(options.limit, findings.length),
      limit: options.limit,
      findings: findings.slice(0, options.limit),
    }))(
      [
        ...duplicateFindings(active, options.duplicateWindowHours),
        ...lifecycleFindings(active, options.now, options.staleHours),
      ].toSorted((left, right) => right.priority - left.priority || left.title.localeCompare(right.title)),
    ))(
    threads.filter(
      ({ archived, recencyAt }) =>
        !archived && options.now - recencyAt <= options.lookbackDays * 86_400,
    ),
  );

const labels: Readonly<Record<FindingKind, string>> = {
  duplicate_exact: "重複候補",
  duplicate_objective: "cwd違いの重複候補",
  human_wait_status: "🚨候補",
  stale_working: "古い⌛️",
  archive_candidate: "アーカイブ候補",
  missing_status: "状態未設定",
};
export const renderMarkdown = (report: AuditReport): string =>
  [
    "# Codexタスク・ライフサイクル監査",
    "",
    `- 生成時刻: ${report.generatedAt}`,
    `- 対象: 直近${report.lookbackDays}日の未アーカイブ ${report.inputCount}件`,
    `- 候補: ${report.findingCount}件（表示 ${report.shownCount}件 / 上限 ${report.limit}件）`,
    "- 境界: 候補の提示だけです。タイトル変更・アーカイブ・タスク作成は行っていません。",
    "",
    ...report.findings.flatMap((finding, index) => [
      `### ${index + 1}. ${labels[finding.kind]}`,
      `- タスク: ${finding.title.replace(/\s+/g, " ").slice(0, 240)}`,
      `- ID: ${finding.ids.join(", ")}`,
      `- 根拠: ${finding.reason}`,
      `- 提案: ${finding.suggestion}`,
      "",
    ]),
    ...(report.findings.length === 0 ? ["候補はありません。", ""] : []),
  ].join("\n");

const usage = `Usage:
  codex-task-audit [--format markdown|json] < threads.json
  codex-task-audit --current [--days 35] [--limit 20] [--stale-hours 48]

The core is JSON input to JSON/Markdown output. --current is the outer launcher
that projects only task metadata from Codex's state DB in read-only mode.`;
const optionNumber = (argv: ReadonlyArray<string>, name: string, fallback: number): Result<number> =>
  ((index) =>
    index < 0
      ? ok(fallback)
      : ((value) =>
          Number.isFinite(value) && value > 0 ? ok(value) : err(`${name} must be positive`))(
          Number(argv[index + 1]),
        ))(argv.findIndex((arg) => arg === name));
const parseArgs = (argv: ReadonlyArray<string>): Result<Args> =>
  argv.includes("--help") || argv.includes("-h")
    ? err(usage)
    : ((formatIndex, limit, staleHours, duplicateWindowHours, lookbackDays) =>
        !limit.ok
          ? limit
          : !staleHours.ok
            ? staleHours
            : !duplicateWindowHours.ok
              ? duplicateWindowHours
              : !lookbackDays.ok
                ? lookbackDays
                : ((format) =>
                    format !== "json" && format !== "markdown"
                      ? err("--format must be markdown or json")
                      : ok({
                          current: argv.includes("--current"),
                          format,
                          limit: Math.floor(limit.value),
                          staleHours: staleHours.value,
                          duplicateWindowHours: duplicateWindowHours.value,
                          lookbackDays: lookbackDays.value,
                        }))(formatIndex < 0 ? "markdown" : argv[formatIndex + 1]))(
      argv.findIndex((arg) => arg === "--format"),
      optionNumber(argv, "--limit", 20),
      optionNumber(argv, "--stale-hours", 48),
      optionNumber(argv, "--duplicate-window-hours", 24),
      optionNumber(argv, "--days", 35),
    );

const rowsFromJson = (raw: string): Result<ReadonlyArray<unknown>> =>
  ((database) =>
    ((valid) =>
      valid === 0
        ? (database.close(), err("stdin must contain valid JSON"))
        : ((rows) => (database.close(), ok(rows)))(
            database
              .prepare(`SELECT
                json_extract(value, '$.id') AS id,
                coalesce(json_extract(value, '$.title'), json_extract(value, '$.name')) AS title,
                json_extract(value, '$.cwd') AS cwd,
                json_extract(value, '$.archived') AS archived,
                coalesce(json_extract(value, '$.createdAt'), json_extract(value, '$.created_at')) AS createdAt,
                coalesce(json_extract(value, '$.recencyAt'), json_extract(value, '$.updatedAt'), json_extract(value, '$.recency_at'), json_extract(value, '$.updated_at')) AS recencyAt,
                coalesce(json_extract(value, '$.mode'), json_extract(value, '$.source'), 'general') AS mode
              FROM json_each(?)`)
              .all(raw),
          ))(
      Number(
        database
          .prepare("SELECT CASE WHEN json_valid(?) THEN json_type(?) = 'array' ELSE 0 END AS valid")
          .get(raw, raw)?.valid ?? 0,
      ),
    ))(new DatabaseSync(":memory:"));
const currentRows = (): Result<ReadonlyArray<unknown>> =>
  ((path) =>
    !existsSync(path)
      ? err(`Codex state DB not found: ${path}`)
      : ((database) =>
          ((columns) =>
            !["id", "title", "cwd", "archived", "created_at", "recency_at", "source", "first_user_message", "agent_role"]
              .every((required) => columns.includes(required))
              ? (database.close(), err("Codex state DB schema is unsupported"))
              : ((rows) => (database.close(), ok(rows)))(
                  database.prepare(`SELECT
                    id, title, cwd, archived, created_at AS createdAt, recency_at AS recencyAt,
                    CASE WHEN first_user_message LIKE 'Automation:%' THEN 'scheduled' ELSE source END AS mode
                  FROM threads
                  WHERE archived = 0
                    AND title <> ''
                    AND agent_role IS NULL
                    AND source IN ('cli', 'vscode')
                    AND title NOT LIKE '<command-name>%'
                  ORDER BY recency_at DESC`).all(),
                ))(
            database.prepare("SELECT name FROM pragma_table_info('threads')").all().flatMap((row) =>
              isRecord(row) && typeof row.name === "string" ? [row.name] : []),
          ))(new DatabaseSync(path, { readOnly: true })))
  (`${process.env.CODEX_HOME ?? `${homedir()}/.codex`}/state_5.sqlite`);
const emit = (args: Args, rows: Result<ReadonlyArray<unknown>>): boolean =>
  !rows.ok
    ? (console.error(`codex-task-audit: ${rows.error}`), (process.exitCode = 1), false)
    : ((decoded) =>
        !decoded.ok
          ? (console.error(`codex-task-audit: ${decoded.error}`), (process.exitCode = 1), false)
          : ((report) => (
              console.log(args.format === "json" ? JSON.stringify(report, null, 2) : renderMarkdown(report)),
              true
            ))(auditThreads(decoded.value, {
              now: Date.now() / 1_000,
              limit: args.limit,
              staleHours: args.staleHours,
              duplicateWindowHours: args.duplicateWindowHours,
              lookbackDays: args.lookbackDays,
            })))(decodeThreads(rows.value));

process.argv[1]?.endsWith("codex-task-audit.ts")
  ? ((args) =>
      args.ok
        ? emit(args.value, args.value.current ? currentRows() : rowsFromJson(readFileSync(0, "utf8")))
        : (console.error(args.error), (process.exitCode = args.error === usage ? 0 : 2), false))(
      parseArgs(process.argv.slice(2)),
    )
  : false;
