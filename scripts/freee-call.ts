import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

type JsonPrimitive = string | number | boolean | null;
type JsonValue =
  | JsonPrimitive
  | ReadonlyArray<JsonValue>
  | { readonly [key: string]: JsonValue };
type Result<T> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: string };
type Service = "accounting" | "hr" | "invoice" | "pm" | "sm";
type Method = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
type QueryValue = JsonPrimitive | ReadonlyArray<JsonPrimitive> | undefined;
type Query = Readonly<Record<string, QueryValue>>;
type FreeeRequest = Readonly<{
  service?: Service;
  method?: Method;
  path: string;
  query?: Query;
  body?: JsonValue;
  company_id?: string | number | false;
}>;
type FreeeConfig = Readonly<{
  clientId: string;
  clientSecret: string;
  currentCompanyId?: string;
  defaultCompanyId?: string;
}>;
type FreeeTokens = Readonly<{
  access_token: string;
  refresh_token: string;
  expires_at: number;
  token_type: string;
  scope: string;
}>;

const baseUrls: Readonly<Record<Service, string>> = {
  accounting: "https://api.freee.co.jp",
  hr: "https://api.freee.co.jp/hr",
  invoice: "https://api.freee.co.jp/iv",
  pm: "https://api.freee.co.jp/pm",
  sm: "https://api.freee.co.jp/sm",
};

const tokenEndpoint = "https://accounts.secure.freee.co.jp/public_api/token";
const freeeConfigDir = join(homedir(), ".config", "freee-mcp");
const configPath = join(freeeConfigDir, "config.json");
const tokensPath = join(freeeConfigDir, "tokens.json");
const refreshSkewMs = 60_000;
const timeoutMs = 60_000;

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

const readJsonFile = <T>(path: string): Result<T> =>
  existsSync(path)
    ? tryResult(() => JSON.parse(readFileSync(path, "utf8")) as T)
    : err(`missing file: ${path}`);

const parseInput = (text: string): Result<FreeeRequest> =>
  ((parsed) =>
    parsed.ok
      ? isRecord(parsed.value) && typeof parsed.value.path === "string"
        ? ok(parsed.value as FreeeRequest)
        : err("input must be a JSON object with a string path")
      : err("stdin must be valid JSON"))(tryResult(() => JSON.parse(text)));

const normalizeService = (service: unknown): Result<Service> =>
  typeof service === "undefined"
    ? ok("accounting")
    : typeof service === "string" && service in baseUrls
      ? ok(service as Service)
      : err(`invalid service: ${String(service)}`);

const normalizeMethod = (method: unknown): Result<Method> =>
  typeof method === "undefined"
    ? ok("GET")
    : ["GET", "POST", "PUT", "PATCH", "DELETE"].includes(String(method))
      ? ok(String(method) as Method)
      : err(`invalid method: ${String(method)}`);

const isSafePath = (path: string): boolean =>
  path.startsWith("/") && !path.startsWith("//") && !path.includes("..");

const companyIdOf = (
  request: FreeeRequest,
  config: FreeeConfig,
): string | number | undefined =>
  request.company_id === false
    ? undefined
    : request.company_id ?? config.currentCompanyId ?? config.defaultCompanyId;

const shouldInjectCompanyId = (
  request: FreeeRequest,
  query: Query,
  companyId: string | number | undefined,
): boolean =>
  request.company_id === false
    ? false
    : typeof companyId === "undefined"
      ? false
      : typeof query.company_id !== "undefined"
        ? false
        : ["/api/1/companies", "/api/1/users/me"].includes(request.path)
          ? false
          : true;

const queryEntries = (query: Query): ReadonlyArray<readonly [string, string]> =>
  Object.entries(query).flatMap(([key, value]) =>
    typeof value === "undefined" || value === null
      ? []
      : Array.isArray(value)
        ? value.map((item) => [key, String(item)] as const)
        : [[key, String(value)] as const],
  );

const appendQuery = (url: URL, query: Query): URL =>
  queryEntries(query).reduce(
    (target, [key, value]) => (target.searchParams.append(key, value), target),
    url,
  );

const buildUrl = (
  request: FreeeRequest,
  service: Service,
  config: FreeeConfig,
): Result<URL> =>
  isSafePath(request.path)
    ? ok(
        appendQuery(
          new URL(request.path.replace(/^\/+/, ""), `${baseUrls[service]}/`),
          ((query, companyId) =>
            shouldInjectCompanyId(request, query, companyId)
              ? { ...query, company_id: companyId }
              : query)(request.query ?? {}, companyIdOf(request, config)),
        ),
      )
    : err("path must be an absolute API path without // or ..");

const isFresh = (tokens: FreeeTokens): boolean =>
  Date.now() + refreshSkewMs < tokens.expires_at;

const tokenBodyOf = (
  config: FreeeConfig,
  tokens: FreeeTokens,
): URLSearchParams =>
  new URLSearchParams({
    grant_type: "refresh_token",
    client_id: config.clientId,
    client_secret: config.clientSecret,
    refresh_token: tokens.refresh_token,
  });

const parseJsonText = (text: string): Result<JsonValue> =>
  text.trim() === "" ? ok({}) : tryResult(() => JSON.parse(text) as JsonValue);

const saveTokens = (tokens: FreeeTokens): FreeeTokens => (
  mkdirSync(dirname(tokensPath), { recursive: true }),
  writeFileSync(tokensPath, JSON.stringify(tokens, null, 2), { mode: 0o600 }),
  tokens
);

const expiresAtOf = (expiresIn: unknown): number =>
  Date.now() + (Number.isFinite(Number(expiresIn)) ? Number(expiresIn) : 3600) * 1000;

const tokensFromRefresh = (
  value: Record<string, unknown>,
  previous: FreeeTokens,
): Result<FreeeTokens> =>
  typeof value.access_token === "string"
    ? ok(
        saveTokens({
          access_token: value.access_token,
          refresh_token:
            typeof value.refresh_token === "string"
              ? value.refresh_token
              : previous.refresh_token,
          expires_at: expiresAtOf(value.expires_in),
          token_type:
            typeof value.token_type === "string"
              ? value.token_type
              : previous.token_type,
          scope: typeof value.scope === "string" ? value.scope : previous.scope,
        }),
      )
    : err("token refresh response did not include access_token");

const refreshedTokens = (
  config: FreeeConfig,
  tokens: FreeeTokens,
): Promise<Result<FreeeTokens>> =>
  fetch(tokenEndpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "User-Agent": "freee-call/1.0",
    },
    body: tokenBodyOf(config, tokens),
    signal: AbortSignal.timeout(timeoutMs),
  })
    .then((response) =>
      response.text().then((text) => ({ response, text }) as const),
    )
    .then(({ response, text }) =>
      response.ok
        ? ((parsed) =>
            parsed.ok && isRecord(parsed.value)
              ? tokensFromRefresh(parsed.value, tokens)
              : err("token refresh returned non-JSON response"))(
            parseJsonText(text),
          )
        : err(`token refresh failed: HTTP ${response.status}`),
    )
    .catch((error) => err(`token refresh failed: ${messageOf(error)}`));

const validTokens = (
  config: FreeeConfig,
  tokens: FreeeTokens,
): Promise<Result<FreeeTokens>> =>
  isFresh(tokens) ? Promise.resolve(ok(tokens)) : refreshedTokens(config, tokens);

const payloadOf = (request: FreeeRequest, method: Method): BodyInit | undefined =>
  ["POST", "PUT", "PATCH"].includes(method)
    ? JSON.stringify(request.body ?? {})
    : undefined;

const callFreee = (
  request: FreeeRequest,
  service: Service,
  method: Method,
  url: URL,
  tokens: FreeeTokens,
): Promise<Result<JsonValue>> =>
  fetch(url.toString(), {
    method,
    headers: {
      Authorization: `Bearer ${tokens.access_token}`,
      "Content-Type": "application/json",
      "User-Agent": "freee-call/1.0",
    },
    body: payloadOf(request, method),
    signal: AbortSignal.timeout(timeoutMs),
  })
    .then((response) =>
      response.text().then((text) => ({ response, text }) as const),
    )
    .then(({ response, text }) =>
      ((parsed) =>
        response.ok
          ? parsed
          : ok({
              ok: false,
              service,
              method,
              path: request.path,
              status: response.status,
              error: parsed.ok ? parsed.value : text,
            }))(parseJsonText(text)),
    )
    .catch((error) => err(`freee request failed: ${messageOf(error)}`));

const usage = {
  usage: "printf '%s\\n' '{\"service\":\"accounting\",\"path\":\"/api/1/companies\"}' | freee-call",
  input: {
    service: "accounting | hr | invoice | pm | sm",
    method: "GET | POST | PUT | PATCH | DELETE",
    path: "/api/1/...",
    query: { limit: 20 },
    body: {},
    company_id: "optional; defaults to ~/.config/freee-mcp currentCompanyId; false disables injection",
  },
} as const;

const render = (value: JsonValue): string => `${JSON.stringify(value, null, 2)}\n`;

const run = (): Promise<Result<JsonValue>> =>
  process.argv.slice(2).includes("--help")
    ? Promise.resolve(ok(usage))
    : ((text) =>
        text.trim() === ""
          ? Promise.resolve(err("missing JSON input on stdin or argv"))
          : ((requestResult, configResult, tokensResult) =>
              requestResult.ok && configResult.ok && tokensResult.ok
                ? ((serviceResult, methodResult) =>
                    serviceResult.ok && methodResult.ok
                      ? ((urlResult) =>
                          urlResult.ok
                            ? validTokens(
                                configResult.value,
                                tokensResult.value,
                              ).then((validTokenResult) =>
                                validTokenResult.ok
                                  ? callFreee(
                                      requestResult.value,
                                      serviceResult.value,
                                      methodResult.value,
                                      urlResult.value,
                                      validTokenResult.value,
                                    )
                                  : Promise.resolve(validTokenResult),
                              )
                            : Promise.resolve(urlResult))(
                          buildUrl(
                            requestResult.value,
                            serviceResult.value,
                            configResult.value,
                          ),
                        )
                      : Promise.resolve(
                          serviceResult.ok ? methodResult : serviceResult,
                        ))(
                    normalizeService(requestResult.value.service),
                    normalizeMethod(requestResult.value.method),
                  )
                : Promise.resolve(
                    requestResult.ok
                      ? configResult.ok
                        ? tokensResult
                        : configResult
                      : requestResult,
                  ))(
              parseInput(text),
              readJsonFile<FreeeConfig>(configPath),
              readJsonFile<FreeeTokens>(tokensPath),
            ))(
        process.argv.slice(2).length > 0
          ? process.argv.slice(2).join(" ")
          : process.stdin.isTTY
            ? ""
            : readFileSync(0, "utf8"),
      );

run().then((result) => (
  process.stdout.write(
    render(result.ok ? result.value : { ok: false, error: result.error }),
  ),
  process.exitCode = result.ok ? 0 : 1
));
