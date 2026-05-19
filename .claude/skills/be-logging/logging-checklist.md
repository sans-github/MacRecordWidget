# BE Logging Review Checklist

Run through every applicable item before declaring logging implementation complete.

## Setup

- [ ] SLF4J used as the abstraction (`org.slf4j.Logger`) -- no direct log4j or Logback imports in application code
- [ ] JSON appender configured (`logstash-logback-encoder` or equivalent) -- plain-text appender only for local dev
- [ ] Access log enabled with pattern that includes `traceId`, status, duration, and remote IP
- [ ] Access log writes to a separate file from application log

## Correlation

- [ ] `TraceIdFilter` registered and runs on all requests
- [ ] `traceId` accepted from `X-Trace-Id` request header (for upstream caller correlation)
- [ ] `X-Trace-Id` set on outbound response so callers can correlate
- [ ] `MDC.clear()` called in a `finally` block -- no context leak across threads

## Format and content

- [ ] Every INFO/WARN/ERROR log line leads with a `snake_case` event name
- [ ] Contextual data expressed as `key=value` pairs (not free-form prose)
- [ ] No PII in any log at any level (emails, names, tokens, passwords, card numbers)
- [ ] No secrets in any log (API keys, DB credentials, JWT payloads)
- [ ] No full request/response body logging at INFO or above
- [ ] No string concatenation in log calls -- SLF4J `{}` parameterization used throughout

## Layer coverage

- [ ] Controller logs request received and request completed (with status + duration)
- [ ] Controller logs WARN on 4xx, ERROR on 5xx with exception
- [ ] Service logs meaningful state transitions for each business operation
- [ ] Repository logs query intent at DEBUG (not INFO)
- [ ] External calls logged with service name, action, and outcome (status + duration)
- [ ] External call errors include response status and truncated body (500 chars max)

## Log levels

- [ ] ERROR used only for unhandled exceptions and system failures -- exception object always attached
- [ ] WARN used for recoverable issues and unexpected-but-non-fatal state
- [ ] INFO used for business touchpoints only -- not chatty operational noise
- [ ] DEBUG and TRACE disabled in staging/prod environment config
