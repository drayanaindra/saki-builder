# Playwright QA Patterns

Reference patterns for `/saki-builder:qa`-generated Playwright tests. Apply these in all generated specs.

---

## Auth Fixture Import

Always import from the project's fixture, NOT from `@playwright/test`:

```typescript
// ✅ Correct — imports custom fixture with teardown
import { test, expect } from '../../fixtures/auth';

// ❌ Wrong — plain @playwright/test has no loginWithToken or teardown
import { test, expect } from '@playwright/test';
```

The relative path `../../fixtures/auth` is correct when the spec is at
`e2e/qa-generated/{slug}/criterion.spec.ts`.

---

## Fixture Usage Pattern

```typescript
import { test, expect } from '../../fixtures/auth';

const TOKEN = process.env.TEST_JWT ?? '';

test('auth fixture bypasses guard', async ({ page, loginWithToken }) => {
  test.skip(!TOKEN, 'TEST_JWT not set — run: cp .env.test.example .env.test');
  await loginWithToken(TOKEN);
  await page.goto('/pos');
  await page.waitForLoadState('networkidle');
  await expect(page).not.toHaveURL(/masuk/);
});
```

---

## Auth survives app init — set migration preconditions (CRITICAL)

The single biggest QA-phase time sink: you inject a token, but the app **clears it on init** before the
page renders, so every auth-gated spec logs out and times out. Symptom = a whole suite failing with
selector/`toBeVisible` timeouts (not assertion mismatches), and the QA phase ballooning to 30–60 min of
retry loops. (Real case: `migrateCookiesIfNeeded()` ran on app init and removed `access_token` /
`refresh_token` whenever `localStorage.cookie_migration_v1` was unset — fresh Playwright contexts always
have empty localStorage, so it wiped the injected session every single test.)

**Before generating specs, grep the app for init-time session resets:**
```bash
grep -rnE "migrat|cookie_migration|localStorage\.(clear|removeItem)|(remove|delete).*(access_token|refresh_token)" src/ | head
```

**If a trap exists, set its PRECONDITION flag alongside the token** (so the migration/reset is a no-op),
not just the token:
```typescript
await page.addInitScript(
  ({ accessToken, refreshToken }) => {
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
    localStorage.setItem('cookie_migration_v1', '1'); // ← satisfy the guard so it does NOT clear tokens
  },
  { accessToken: token, refreshToken: 'placeholder-refresh' },
);
```
Generalize: whatever flag the init guard checks (`*_migration_v*`, `onboarded`, a schema-version key),
seed it. This is project-specific *content* but the same *rule* everywhere — find the guard, satisfy it.

---

## globalSetup + storageState (authenticate once) — preferred

Per-test `addInitScript` re-establishes auth on every test and re-fights any init guard each time.
**Prefer authenticating ONCE in `globalSetup` and persisting full storage** (cookies + localStorage,
including the precondition flag above) — every spec starts already-authenticated, far fewer timeouts,
set up once per project. This mechanism is 100% portable; only the login call + storage keys differ per app.

```typescript
// e2e/global-setup.ts
import { chromium, type FullConfig } from '@playwright/test';
export default async function globalSetup(config: FullConfig) {
  const { baseURL } = config.projects[0].use;
  const browser = await chromium.launch();
  const page = await browser.newPage();
  // 1. obtain a session — API login (preferred) or drive the UI login form:
  const token = process.env.TEST_JWT ?? '';            // or: POST baseURL+'/api/login', read token
  // 2. seed storage BEFORE app code runs, incl. any init-guard precondition (see section above):
  await page.addInitScript((t) => {
    localStorage.setItem('access_token', t);
    localStorage.setItem('refresh_token', 'placeholder-refresh');
    localStorage.setItem('cookie_migration_v1', '1'); // ← the trap precondition, persisted into state
  }, token);
  await page.goto(baseURL!);
  await page.waitForLoadState('networkidle');
  // 3. persist the authenticated state for all specs to reuse:
  await page.context().storageState({ path: 'e2e/.auth/state.json' });
  await browser.close();
}
```
```typescript
// playwright.config.ts
export default defineConfig({
  globalSetup: './e2e/global-setup.ts',
  use: { storageState: 'e2e/.auth/state.json' /*, baseURL, ... */ },
});
```
Add `e2e/.auth/` to `.gitignore` (it holds a real token). Specs then need no `loginWithToken` call —
they open already-authenticated. Keep the per-test fixture (above) as the fallback when a project can't
run globalSetup (e.g. no headless-obtainable token).

---

## `addInitScript` — Safe Object Form

Never use string interpolation. Always use the object form:

```typescript
// ✅ Safe — no string interpolation, args serialized by Playwright
await page.addInitScript(
  ({ accessToken, refreshToken }: { accessToken: string; refreshToken: string }) => {
    localStorage.setItem('access_token', accessToken);
    localStorage.setItem('refresh_token', refreshToken);
  },
  { accessToken: token, refreshToken: 'placeholder-refresh' },
);

// ❌ Unsafe — string interpolation can break with special characters
await page.addInitScript(`localStorage.setItem('access_token', '${token}')`);
```

⚠️ Setting the token is not enough if the app clears it on init — see **"Auth survives app init"**
above and seed the guard's precondition flag in the same script.

---

## `waitForLoadState`

Mandate after every `page.goto()`:

```typescript
await page.goto('/dashboard');
await page.waitForLoadState('networkidle');
// Now safe to query DOM
```

Valid in `@playwright/test` ≥ 1.0. If deprecation warning appears in a future version,
replace with: `await page.waitForLoadState('domcontentloaded'); await page.waitForSelector('[data-testid]');`

---

## Teardown — Fixture `use()` Sandwich

`localStorage.clear()` teardown is built into the `loginWithToken` fixture.
**Do NOT** add `test.afterEach` manually in generated specs — the fixture handles it:

```typescript
// e2e/fixtures/auth.ts
export const test = base.extend<AuthFixtures>({
  loginWithToken: async ({ page }, use) => {
    await use(async (token: string) => {
      // setup: inject token
      await page.addInitScript(fn, args);
    });
    // teardown: runs after every test automatically
    await page.evaluate(() => localStorage.clear());
  },
});
```

---

## Selector Preference

Prefer `data-testid` attributes over CSS selectors or text matchers:

```typescript
// ✅ Stable
await page.getByTestId('submit-order-button').click();

// ⚠️ Fragile — breaks on copy changes
await page.getByText('Buat Pesanan').click();
```

---

## TEST_JWT Environment Variable

`TEST_JWT` is loaded via `dotenv.config({ path: '.env.test' })` in `playwright.config.ts`.
It is NOT auto-loaded by Playwright from `.env.test` — the config file must load it explicitly.

Generate a long-lived (≥ 24h) token so refresh never triggers mid-test.
If the app uses short-lived tokens, stub the refresh endpoint instead.

---

## CI Browser Install

```bash
cd frontend && npx playwright install chromium
```

Check: `ls ~/Library/Caches/ms-playwright/chromium-* 2>/dev/null || ls ~/.cache/ms-playwright/chromium-* 2>/dev/null`
