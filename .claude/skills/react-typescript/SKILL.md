---
name: react-typescript
description: React 18 + TypeScript project structure, component patterns, Redux Toolkit state management, TanStack Query data fetching, React Router v6 routing, and code style conventions. Use when building, reviewing, or making tech stack decisions for a React application.
---

# React + TypeScript Best Practices

## Stack at a glance

| Tool | Job | When you feel it |
|---|---|---|
| React 18 | Build UI from components | Every `.jsx`/`.tsx` file you write |
| TypeScript | Type safety | Compile-time errors before bugs hit runtime |
| Redux Toolkit | Global state | Shared data (user, auth, cart) across many components |
| TanStack Query | Server state + data fetching | Async data, caching, loading/error states |
| React Router v6 | Client-side routing | URL changes without full page reload |
| Playwright | E2E testing | Simulates real user clicking through the app |
| Vite | Dev server + bundler | Instant hot reload in dev, optimized output for prod |
| @vitejs/plugin-react | JSX + Fast Refresh | React works inside Vite |

**How they connect:**

```
You write TypeScript + JSX
        │
        ▼
   Vite compiles it, serves it in dev (hot reload)
        │
        ▼
   React 18 renders the UI
        ├── Redux Toolkit manages shared state (user, auth, cart)
        └── TanStack Query fetches + caches server data
                │
                ▼
          Spring Boot API  ◄─── React fetches, TypeScript types the response
        │
        ▼
   Playwright tests the full flow in a real browser
        │
        ▼
   Vite bundles for production + deploy
```

---

## Project Setup

- **Build tool:** Vite with `@vitejs/plugin-react`
- **Language:** TypeScript strict mode (`"strict": true` in tsconfig)
- **Code style:** ESLint + Prettier; enforced via CI (`eslint --max-warnings 0`)

### Key tsconfig settings

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "moduleResolution": "bundler",
    "jsx": "react-jsx"
  }
}
```

### Key dependencies

```json
{
  "dependencies": {
    "react": "^18",
    "react-dom": "^18",
    "react-router-dom": "^6",
    "@reduxjs/toolkit": "^2",
    "react-redux": "^9",
    "@tanstack/react-query": "^5"
  },
  "devDependencies": {
    "typescript": "^5",
    "vite": "^5",
    "@vitejs/plugin-react": "^4",
    "eslint": "^9",
    "prettier": "^3"
  }
}
```

---

## Project structure

Organize by feature/domain, not by type:

```
src/
├── features/
│   ├── orders/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── store/          # slice + selectors
│   │   └── api/            # query hooks
│   └── users/
├── shared/
│   ├── components/         # reusable UI primitives
│   ├── hooks/
│   └── utils/
└── app/
    ├── store.ts
    ├── router.tsx
    └── App.tsx
```

---

## Components

- Functional components only -- no class components
- One component per file; filename matches component name (`OrderCard.tsx`)
- Props typed with `interface`; use `type` only for unions or intersections
- Named exports for shared components; default exports acceptable for page-level routes

### Where a component lives

| Component type | Location |
|---|---|
| Used by more than one feature, or has no feature-specific logic (Toast, Banner, FormField, etc.) | `src/shared/components/` |
| UI primitives always | `src/shared/components/` |
| Belongs to a single feature and has feature-specific logic | `src/features/<feature>/components/` |
| When in doubt: if you could imagine reusing it in a different feature without changing it, it goes in `src/shared/components/`.

```tsx
interface OrderCardProps {
  orderId: string;
  status: OrderStatus;
  onCancel?: () => void;
}

export function OrderCard({ orderId, status, onCancel }: OrderCardProps) {
  return (
    <div>...</div>
  );
}
```

---

## State management (Redux Toolkit)

Use Redux Toolkit exclusively -- never raw Redux. UI-local state (modals, form fields) stays in `useState`; only shared or async state goes into Redux.

```ts
// features/orders/store/ordersSlice.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';

const ordersSlice = createSlice({
  name: 'orders',
  initialState,
  reducers: {
    setFilter(state, action: PayloadAction<string>) {
      state.filter = action.payload;
    },
  },
});
```

### Typed hooks

```ts
// app/store.ts
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
export const useAppSelector = useSelector.withTypes<RootState>();
export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
```

Always use `useAppSelector` and `useAppDispatch` -- never the untyped versions.

---

## Data fetching (TanStack Query)

Use TanStack Query for all server state. No manual `useEffect` for data fetching.

```ts
// features/orders/api/useOrders.ts
const orderKeys = {
  all: ['orders'] as const,
  list: () => [...orderKeys.all, 'list'] as const,
  detail: (id: string) => [...orderKeys.all, id] as const,
};

export function useOrders() {
  return useQuery({
    queryKey: orderKeys.list(),
    queryFn: () => fetch('/api/v1/orders').then(r => r.json()),
  });
}

export function useCreateOrder() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (data: CreateOrderRequest) =>
      fetch('/api/v1/orders', { method: 'POST', body: JSON.stringify(data) }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: orderKeys.all }),
  });
}
```

---

## Routing (React Router v6)

Use `createBrowserRouter` with `RouterProvider`. Lazy-load feature routes.

```tsx
// app/router.tsx
const Orders = React.lazy(() => import('../features/orders/OrdersPage'));

export const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { path: 'orders', element: <Suspense fallback={<Spinner />}><Orders /></Suspense> },
    ],
  },
]);
```

---

## Code style

| Convention | Value |
|---|---|
| Linter | ESLint with `@typescript-eslint`, `eslint-plugin-react`, `eslint-plugin-react-hooks` |
| Formatter | Prettier |
| CI gate | `eslint --max-warnings 0` -- warnings are errors in CI |
| Imports | Absolute imports via `paths` in tsconfig; no relative `../../` climbing |

---

## Resources

- Load `fe-test-checklist.md` before declaring any FE test code complete -- required by `test-review-rule.md`.
