---
name: fe-logging
description: Frontend logging conventions for React/TypeScript -- structured JSON output, trace ID generation and propagation to backend, log levels, error boundaries, API call logging, and Splunk/Datadog compatible format. Use when implementing or reviewing any logging in the frontend.
---

# Frontend Logging Conventions

## Logging approach

The browser has no file system, so "logging" on the FE means:

1. **Shipping logs to a backend collector** (preferred for production) -- a log drain endpoint, Splunk HEC, Datadog Browser SDK, or your own ingest API.
2. **`console.*` as fallback** for local dev only.

Never rely on `console.log` in production. It goes nowhere and gets lost.

## Logger library

Use a thin structured logger. Options in order of preference:

| Env | Library |
|-----|---------|
| Browser SPA | `loglevel` + custom transport, or Datadog Browser Logs SDK, or a thin wrapper around `fetch` to a log ingest endpoint |
| SSR / Node (Next.js) | `pino` with JSON output |

Wrap the chosen library behind a single `logger` module so you can swap the transport without touching call sites:

```ts
// src/lib/logger.ts
import log from 'loglevel';

const logger = {
  info:  (event: string, ctx?: Record<string, unknown>) => log.info(serialize(event, 'INFO', ctx)),
  warn:  (event: string, ctx?: Record<string, unknown>) => log.warn(serialize(event, 'WARN', ctx)),
  error: (event: string, error?: unknown, ctx?: Record<string, unknown>) => log.error(serialize(event, 'ERROR', error, ctx)),
  debug: (event: string, ctx?: Record<string, unknown>) => log.debug(serialize(event, 'DEBUG', ctx)),
};

export default logger;
```

## Correlation IDs (trace generation and propagation)

The FE generates a `traceId` per request and sends it to the backend. This is the conventional approach per the W3C Trace Context spec -- the initiating component (the browser) owns the root trace ID. The backend inherits it, propagates it through all downstream logs, and echoes it back on the response for confirmation.

**Trace ID format:** 128-bit random value as 32 lowercase hex characters -- OTel-compatible, no SDK required.

```ts
// src/lib/traceId.ts
export const generateTraceId = (): string =>
  Array.from(crypto.getRandomValues(new Uint8Array(16)))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
```

**On every API call:** generate a traceId before the request, send it as `X-Trace-Id` on the request header, and include it in logs from the start -- not just after the response arrives.

**For user sessions:** generate a `sessionId` at app boot (stored in memory, not localStorage) to correlate all events in a single session.

```ts
const traceId = generateTraceId();
logger.info('api_call_start', { endpoint, method, traceId });
const response = await fetch('/api/orders', {
  headers: { 'X-Trace-Id': traceId },
});
logger.info('api_call_complete', { endpoint, method, status: response.status, durationMs, traceId });
```

Include `sessionId` and `traceId` in every log event.

## Structured JSON format

Every log event must be a JSON object with these fields:

```json
{
  "timestamp": "2026-04-20T10:23:01.456Z",
  "level": "INFO",
  "event": "api_call_complete",
  "sessionId": "sess-abc123",
  "traceId": "trace-xyz789",
  "page": "/checkout",
  "endpoint": "/api/orders",
  "status": 201,
  "durationMs": 342
}
```

## Splunk / Datadog key-value pairs in event name

Lead every log with a `snake_case` event name, then pass structured context as an object (not a string). The serializer emits `key=value` pairs in the message field:

```ts
logger.info('checkout_step_completed', { step: 'payment', orderId: 'ORD-9981', durationMs: 1200 });
// → message: "checkout_step_completed step=payment orderId=ORD-9981 durationMs=1200"
```

## Log levels

| Level | When to use |
|-------|-------------|
| `ERROR` | Unhandled exceptions, failed API calls (5xx), React error boundary catches |
| `WARN` | Recoverable failures: 4xx API responses, retry attempts, degraded feature state |
| `INFO` | User actions, page transitions, API call outcomes (2xx), business events |
| `DEBUG` | Component render details, state diffs, feature flag evaluations. Off in prod. |

Production default: `INFO` and above. `DEBUG` only in local dev.

## What to log and where

### API calls

Log every outbound fetch/axios call:

```ts
logger.info('api_call_start', { endpoint, method });
// ... await ...
logger.info('api_call_complete', { endpoint, method, status, durationMs, traceId });
// on error:
logger.error('api_call_failed', error, { endpoint, method, status, durationMs, traceId });
```

### Page / route transitions

```ts
logger.info('page_view', { page: location.pathname, referrer: document.referrer, sessionId });
```

### User actions (meaningful ones)

Log actions that have business meaning -- not every click. Examples: form submit, checkout initiated, filter applied, item added to cart.

```ts
logger.info('checkout_initiated', { cartSize: items.length, totalAmount });
```

### React error boundaries

```tsx
componentDidCatch(error: Error, info: ErrorInfo) {
  logger.error('react_error_boundary', error, { componentStack: info.componentStack, page: window.location.pathname });
}
```

### Auth events

```ts
logger.info('user_login', { method: 'sso' }); // no userId in logs -- PII
logger.info('user_logout', { sessionDurationMs });
logger.warn('auth_token_refresh_failed', { reason: error.message });
```

## Hard constraints

- **Never log PII.** No email addresses, names, user IDs, phone numbers, addresses in any log at any level.
- **Never log auth tokens, passwords, or session tokens.** Not even at DEBUG.
- **Never log full API request or response bodies** -- they may contain PII or secrets.
- **Never use `console.log` outside local dev.** It does not ship to any collector.
- **Never log Redux state snapshots** -- they typically contain PII and secrets.
- Truncate any error message that might echo user input to 500 chars max.

## When to apply

Load `logging-checklist.md` before declaring any frontend logging implementation complete -- new pages, new API calls, or changes to the logger module. Items that genuinely do not apply must be noted as out of scope, not silently skipped. EM verifies the checklist was run during PR approval.
