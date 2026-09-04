---
name: jsdom-location-mocking
description: window.location.assign is unmockable in jsdom — use behavioral assertions instead
metadata:
  type: feedback
---

`window.location.assign` on the jsdom Location instance has `configurable: false, writable: false`. It cannot be mocked by any standard jest technique:

- `delete (window as any).location` — silently returns `false`, property unchanged
- `Object.defineProperty(window, 'location', { value: ... })` — throws "Cannot redefine property"
- `jest.spyOn(window.location, 'assign')` — throws "Cannot assign to read only property"
- `Object.defineProperty(Location.prototype, 'assign', ...)` — has no effect; `assign` is an own property on the instance, not the prototype
- Direct assignment `(window.location as any).assign = fn` — throws in strict mode

**Why:** jsdom implements the browser Location API faithfully, including its non-configurable properties.

**How to apply:** For components that call `window.location.assign` (e.g. auth guards doing hard redirects), test behavioral output instead:
- Assert component renders `null` / hides children (the visual consequence of the redirect)
- Assert `router.replace` was NOT called (confirming we hit the assign branch, not the router branch)
- Leave `window.location.assign` verification to E2E/integration tests

**Corollary (2026-05-28):** `window.location` itself also cannot be redefined via `Object.defineProperty` — it throws "Cannot redefine property: location". If your hook uses `window.location.search` internally, mock `URLSearchParams` instead:

```typescript
let mockParams: URLSearchParams;
jest.spyOn(global, 'URLSearchParams').mockImplementation(() => mockParams);

beforeEach(() => {
  mockParams = new (jest.requireActual('url').URLSearchParams)('?ref=VALUE');
});
```

`jest.requireActual('url').URLSearchParams` gives you a real implementation to construct instances without the global spy interfering.

[[lessons-learned]]
