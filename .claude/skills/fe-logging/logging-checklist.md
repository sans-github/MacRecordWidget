# FE Logging Review Checklist

Run through every applicable item before declaring logging implementation complete.

## Setup

- [ ] A single `logger` module wraps the chosen library -- no direct `console.log` calls in production code
- [ ] Logger ships to a collector in staging/prod (Splunk HEC, Datadog Browser SDK, or ingest endpoint)
- [ ] Log level set to INFO in prod, DEBUG only in local dev
- [ ] `sessionId` generated at app boot and included in every log event

## Correlation

- [ ] `generateTraceId()` utility exists in `src/lib/traceId.ts` -- 32 lowercase hex chars, OTel-compatible
- [ ] `X-Trace-Id` sent as a request header on every outbound API call, using the locally generated traceId
- [ ] `traceId` present on `api_call_start` log (before the request, not just after)
- [ ] `sessionId` and `traceId` present on every log line

## Format and content

- [ ] Every log event leads with a `snake_case` event name
- [ ] Context passed as a structured object (not a concatenated string)
- [ ] No PII in any log (emails, names, phone numbers, addresses, user IDs)
- [ ] No auth tokens, passwords, or session tokens at any log level
- [ ] No full API request or response bodies logged
- [ ] No Redux state snapshots logged
- [ ] Error messages that might echo user input truncated to 500 chars

## Coverage

- [ ] Every outbound API call logged at start and completion (with status + duration + traceId)
- [ ] 5xx API responses logged at ERROR with error object
- [ ] 4xx API responses logged at WARN
- [ ] Page / route transitions logged at INFO
- [ ] Meaningful user actions logged at INFO (form submit, checkout, key interactions)
- [ ] React error boundary `componentDidCatch` logs at ERROR with component stack
- [ ] Auth events (login, logout, token refresh failure) logged at appropriate level

## Log levels

- [ ] ERROR used only for unhandled exceptions, 5xx failures, error boundary catches
- [ ] WARN used for 4xx responses, retries, degraded feature state
- [ ] INFO used for business events and API outcomes -- not every render or state change
- [ ] DEBUG disabled in staging/prod
