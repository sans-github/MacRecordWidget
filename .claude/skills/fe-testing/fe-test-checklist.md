# FE Test Review Checklist

## Component tests

- [ ] Tests use React Testing Library -- no Enzyme or direct DOM manipulation
- [ ] Queries use accessible selectors (`getByRole`, `getByLabelText`, `getByText`)
- [ ] No `getByTestId` unless no accessible alternative exists
- [ ] `userEvent` used for interactions, not `fireEvent`
- [ ] Async updates wrapped in `waitFor` or use `findBy*` queries
- [ ] Tests follow Arrange-Act-Assert (AAA) pattern
- [ ] Each test covers exactly one behavior
- [ ] Tests are independent -- no shared mutable state, no ordering dependencies

## Naming

- [ ] Test file has `.test.tsx` or `.test.ts` suffix co-located with the component
- [ ] E2E file lives in `tests/` with `.spec.ts` suffix
- [ ] `describe` block names the component or feature
- [ ] `it` or `test` descriptions read as plain English sentences

## Mocking

- [ ] Network requests mocked with MSW -- not `vi.mock(fetch)` or manual stubs
- [ ] MSW handlers live in `src/test/handlers.ts`
- [ ] Handlers reset after each test (`server.resetHandlers()`)
- [ ] Only external dependencies mocked -- never mock your own components

## Redux / state

- [ ] Components under test wrapped with required providers (Redux store, QueryClient, Router)
- [ ] Use a real store in tests, not mocked dispatch -- test the integrated behavior
- [ ] Selector logic tested via `renderHook` with a real store, not unit-tested in isolation

## E2E (Playwright)

- [ ] Tests cover critical user journeys only -- not component-level behavior
- [ ] Locators use `getByRole`, `getByLabel`, `getByText` -- no CSS selectors or XPath
- [ ] `page.waitForLoadState` or `expect(...).toBeVisible()` used instead of arbitrary waits
- [ ] Tests run against the built app in CI (`npm run build && npm run preview`)
- [ ] Trace enabled on first retry (`trace: 'on-first-retry'` in config)

## Coverage

- [ ] Happy path tested
- [ ] Error states tested (API failure, validation errors)
- [ ] Loading and empty states tested
- [ ] Accessibility: interactive elements reachable by keyboard in tests
