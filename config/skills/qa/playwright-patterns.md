# Playwright QA Patterns

Reference patterns for `/qa`-generated Playwright tests. Apply these in all generated specs.

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
