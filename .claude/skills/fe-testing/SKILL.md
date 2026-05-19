---
name: fe-testing
description: React frontend testing conventions covering unit tests with Vitest + React Testing Library, component tests, and E2E tests with Playwright. Use when writing, reviewing, or evaluating FE test code.
---

# Frontend Testing

## Test types

| Type | Tool | Scope | When to use |
|---|---|---|---|
| Unit / component | Vitest + React Testing Library | Single component or hook | Business logic, user interactions, form behavior |
| Integration | Vitest + RTL + MSW | Multiple components + API | Feature flows with mocked network |
| E2E | Playwright | Full browser | Critical user journeys end-to-end |

---

## Setup

```ts
// vite.config.ts
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
  },
});
```

```ts
// src/test/setup.ts
import '@testing-library/jest-dom';
```

---

## Component tests (Vitest + RTL)

Test behavior, not implementation. Never assert on component internals, class names, or state directly.

```tsx
// OrderCard.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { OrderCard } from './OrderCard';

describe('OrderCard', () => {
  it('calls onCancel when cancel button is clicked', () => {
    const onCancel = vi.fn();
    render(<OrderCard orderId="123" status="pending" onCancel={onCancel} />);
    fireEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(onCancel).toHaveBeenCalledOnce();
  });
});
```

### Rules

- Query by role or accessible name -- `getByRole`, `getByLabelText`, `getByText`
- Never use `getByTestId` unless no accessible alternative exists
- Prefer `userEvent` over `fireEvent` for realistic interaction simulation
- Wrap async updates in `waitFor` or use `findBy*` queries

---

## API mocking (MSW)

Use Mock Service Worker to intercept network requests in tests -- not `jest.mock` or manual fetch stubs.

```ts
// src/test/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/v1/orders', () => HttpResponse.json([{ id: '1', status: 'pending' }])),
];
```

```ts
// src/test/setup.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

---

## Hook tests

Use `renderHook` from `@testing-library/react` for custom hooks. Wrap with required providers.

```ts
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClientProvider, QueryClient } from '@tanstack/react-query';
import { useOrders } from './useOrders';

function wrapper({ children }: { children: React.ReactNode }) {
  return <QueryClientProvider client={new QueryClient()}>{children}</QueryClientProvider>;
}

it('fetches orders', async () => {
  const { result } = renderHook(() => useOrders(), { wrapper });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toHaveLength(1);
});
```

---

## E2E tests (Playwright)

```ts
// tests/orders.spec.ts
import { test, expect } from '@playwright/test';

test('user can cancel a pending order', async ({ page }) => {
  await page.goto('/orders');
  await page.getByRole('button', { name: /cancel/i }).first().click();
  await expect(page.getByText('Order cancelled')).toBeVisible();
});
```

### Playwright config

```ts
// playwright.config.ts
export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
});
```

### Rules

- Use `page.getByRole` and `page.getByLabel` -- no CSS selectors or XPath
- E2E tests cover critical user journeys only -- not every component
- Run E2E in CI against the built app (`npm run build && npm run preview`)

---

## Running tests

```bash
npm run test          # unit + component (watch mode)
npm run test:run      # unit + component (CI, single run)
npx playwright test   # E2E
```

---

## Resources

- Load `fe-test-checklist.md` before declaring any FE test code complete -- required by `test-review-rule.md`.
