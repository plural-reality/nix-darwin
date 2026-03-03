---
name: qa-engineer
description: >
  Playwright E2E testing patterns for Next.js + Supabase projects.
  Use when: writing E2E tests, setting up Playwright infrastructure, configuring
  smoke/authenticated/skip test projects, creating auth fixtures with Inbucket,
  debugging test failures, adding pre-push E2E gates, or designing persona-based
  test scenarios. Covers the full testing lifecycle from infrastructure setup
  through CI integration.
---

# QA Engineer — Playwright E2E for Next.js + Supabase

## Architecture: 3-Project Pattern

Split E2E tests into three Playwright projects based on infrastructure requirements:

| Project | Directory | Prerequisites | When to Run |
|---------|-----------|--------------|-------------|
| **smoke** | `e2e/smoke/` | None (dev server only) | pre-push, every CI run |
| **authenticated** | `e2e/authenticated/` | Supabase local (`supabase start`) | CI, manual `test:e2e:all` |
| **skip** | `e2e/skip/` | N/A (placeholder) | Never (skipped by design) |

### Why This Split?

- **smoke** runs fast without Docker — safe for pre-push hooks
- **authenticated** tests real auth flows via Supabase + Inbucket — runs in CI where Supabase can be started
- **skip** documents future features as executable specs — enables `test.describe.skip()` to track unimplemented scenarios

### Playwright Config

```typescript
// playwright.config.ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",
  use: {
    baseURL: "http://localhost:3000",  // adjust per project
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "smoke",
      testDir: "./e2e/smoke",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "authenticated",
      testDir: "./e2e/authenticated",
      use: { ...devices["Desktop Chrome"] },
      ...(process.env.SUPABASE_E2E ? {} : { grep: /@skip-without-supabase/ }),
    },
    {
      name: "skip",
      testDir: "./e2e/skip",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
});
```

## Inbucket Auth Fixture Pattern

Supabase local captures all emails via Inbucket at `http://127.0.0.1:54324`. This enables testing magic link auth without real email delivery.

### Fixture Files

**`e2e/fixtures/test-users.ts`** — Unique email generator

```typescript
let counter = 0;

export function uniqueEmail(prefix = "e2e-test"): string {
  return `${prefix}-${Date.now()}-${++counter}@test.local`;
}

export function mailboxFromEmail(email: string): string {
  return email.split("@")[0];
}
```

**`e2e/fixtures/inbucket.ts`** — Inbucket API helper

```typescript
const INBUCKET_BASE = "http://127.0.0.1:54324";

export async function waitForEmail(mailbox: string, options?: {
  timeout?: number;
  subject?: string;
}): Promise<InbucketMessageBody> {
  const timeout = options?.timeout ?? 10_000;
  const start = Date.now();
  let delay = 250;

  while (Date.now() - start < timeout) {
    const res = await fetch(
      `${INBUCKET_BASE}/api/v1/mailbox/${encodeURIComponent(mailbox)}`
    );
    if (res.ok) {
      const messages = await res.json();
      const match = options?.subject
        ? messages.find((m: any) => m.subject.includes(options.subject!))
        : messages[messages.length - 1];
      if (match) {
        const body = await fetch(
          `${INBUCKET_BASE}/api/v1/mailbox/${encodeURIComponent(mailbox)}/${match.id}`
        );
        if (body.ok) return body.json();
      }
    }
    await new Promise((r) => setTimeout(r, delay));
    delay = Math.min(delay * 1.5, 2000);
  }
  throw new Error(`No email for "${mailbox}" within ${timeout}ms`);
}

export function extractMagicLink(html: string): string {
  const patterns = [
    /href="(http[^"]*\/auth\/confirm[^"]*)"/,
    /href="(http[^"]*\/auth\/v1\/verify[^"]*)"/,
    /href="(http[^"]*(?:token|code)[^"]*)"/,
  ];
  for (const p of patterns) {
    const m = html.match(p);
    if (m?.[1]) return m[1];
  }
  throw new Error("Could not extract magic link from email HTML");
}

export async function clearMailbox(mailbox: string): Promise<void> {
  await fetch(
    `${INBUCKET_BASE}/api/v1/mailbox/${encodeURIComponent(mailbox)}`,
    { method: "DELETE" }
  );
}
```

**`e2e/fixtures/auth.ts`** — Authenticated page fixture

```typescript
import { test as base, expect, type Page } from "@playwright/test";
import { waitForEmail, extractMagicLink, clearMailbox } from "./inbucket";
import { uniqueEmail, mailboxFromEmail } from "./test-users";

type AuthFixtures = {
  authenticatedPage: Page;
  testEmail: string;
};

/* eslint-disable react-hooks/rules-of-hooks */
export const test = base.extend<AuthFixtures>({
  testEmail: async ({}, use) => {
    await use(uniqueEmail("auth"));
  },
  authenticatedPage: async ({ page, testEmail }, use) => {
    const mailbox = mailboxFromEmail(testEmail);
    await clearMailbox(mailbox);

    await page.goto("/login");
    // Fill email and submit — adjust selectors per project
    await page.getByPlaceholder("you@example.com").fill(testEmail);
    await page.getByRole("button", { name: /送信|Sign in|Submit/ }).click();

    const email = await waitForEmail(mailbox);
    const magicLink = extractMagicLink(email.body.html);
    await page.goto(magicLink);
    await page.waitForURL((url) => !url.pathname.includes("/login"), {
      timeout: 15_000,
    });

    await use(page);
  },
});
export { expect };
```

## Persona-Based Test Design

Organize authenticated tests by user persona. Each persona maps to a real user journey through the product.

### Pattern

```
e2e/authenticated/
├── visitor-to-user.spec.ts    # Persona: first-time visitor → sign up
├── creator-flow.spec.ts       # Persona: content creator → create → manage
├── respondent-flow.spec.ts    # Persona: respondent → interact → result
└── admin-flow.spec.ts         # Persona: admin → manage → configure
```

### Key Principles

1. **One persona per file** — each spec tells a complete user story
2. **Mock external APIs** — use `page.route()` for AI/payment APIs to avoid external dependencies
3. **Auth via fixture** — use `authenticatedPage` for all logged-in scenarios
4. **Defensive selectors** — use `.or()` chains for UI elements that may vary:
   ```typescript
   const button = page
     .getByRole("button", { name: "作成" })
     .or(page.getByRole("button", { name: "Create" }));
   ```

### Skip Tests for Unimplemented Features

```typescript
// e2e/skip/pricing-plans.spec.ts
import { test } from "@playwright/test";

test.describe.skip("Pricing plan enforcement", () => {
  test("free plan limits to N items per month", async ({ page }) => {
    // TODO: implement when pricing is live
  });
});
```

## npm Scripts

```json
{
  "test:e2e": "playwright test --project=smoke",
  "test:e2e:all": "SUPABASE_E2E=true playwright test",
  "test:e2e:auth": "SUPABASE_E2E=true playwright test --project=authenticated",
  "test:e2e:ui": "playwright test --ui",
  "preflight": "npm run lint && npm test && npm run build && npm run test:e2e"
}
```

## Pre-Push Hook

Add smoke E2E to the preflight check that blocks `git push`:

```bash
#!/bin/sh
# .git/hooks/pre-push
echo "Running preflight checks..."
npm run preflight
if [ $? -ne 0 ]; then
  echo "Preflight failed. Push aborted."
  exit 1
fi
```

Install via `scripts/install-hooks.sh` (since `.git/hooks/` is not tracked by git).

## CI Integration (GitHub Actions)

Add two E2E jobs after `build`:

```yaml
e2e-smoke:
  runs-on: ubuntu-latest
  needs: build
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: 20, cache: npm }
    - run: npm ci
    - run: npx playwright install --with-deps chromium
    - run: npm run build
    - run: npx playwright test --project=smoke
    - uses: actions/upload-artifact@v4
      if: ${{ !cancelled() }}
      with:
        name: playwright-report-smoke
        path: playwright-report/
        retention-days: 7

e2e-authenticated:
  runs-on: ubuntu-latest
  needs: build
  env:
    SUPABASE_E2E: "true"
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with: { node-version: 20, cache: npm }
    - uses: supabase/setup-cli@v1
      with: { version: latest }
    - run: |
        supabase start
        ANON_KEY=$(supabase status --output json | jq -r '.ANON_KEY // .API.ANON_KEY // empty')
        echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=$ANON_KEY" >> $GITHUB_ENV
    - run: npm ci
    - run: npx playwright install --with-deps chromium
    - run: npm run build
    - run: npx playwright test --project=authenticated
    - uses: actions/upload-artifact@v4
      if: ${{ !cancelled() }}
      with:
        name: playwright-report-authenticated
        path: playwright-report/
        retention-days: 7
```

## Debugging

### Playwright Report

```bash
npx playwright show-report
```

### Trace Viewer

Failed tests save traces to `test-results/`. Open with:

```bash
npx playwright show-trace test-results/<folder>/trace.zip
```

### Inbucket Web UI

Browse `http://127.0.0.1:54324` to inspect captured emails.

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `waitForEmail` timeout | Supabase not running | `supabase start` |
| Magic link extraction fails | Email HTML format changed | Update `extractMagicLink` patterns |
| Auth redirect loop | PKCE callback misconfigured | Check `supabase/config.toml` `site_url` |
| Smoke tests fail in CI | Dev server not starting | Verify `webServer.command` and port in config |

## Adding a New Test

### Smoke Test (no Supabase)

1. Create `e2e/smoke/your-test.spec.ts`
2. Import from `@playwright/test` directly
3. Test pages, redirects, forms, static content

### Authenticated Test (needs Supabase)

1. Create `e2e/authenticated/your-test.spec.ts`
2. Import `{ test, expect }` from `../fixtures/auth`
3. Use `authenticatedPage` fixture for logged-in tests
4. Mock external APIs with `page.route()`

### Skip Test (unimplemented feature)

1. Create `e2e/skip/your-feature.spec.ts`
2. Wrap in `test.describe.skip()`
3. When implemented: remove `skip`, move to `smoke/` or `authenticated/`
