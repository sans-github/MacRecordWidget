---
name: be-logging
description: Backend logging conventions for Java/Spring Boot -- structured JSON output, OTEL-based trace correlation, access vs application log separation, Splunk/Datadog compatible format, and per-layer logging guidance. Use when implementing or reviewing any logging in the backend.
---

# Backend Logging Conventions

## Logging stack

- **Abstraction:** SLF4J (`org.slf4j.Logger`) -- always code against the abstraction, never against the implementation directly.
- **Implementation:** Logback (Spring Boot default) or Log4j2. Do not use log4j v1 -- it is deprecated and unsupported.
- **Format:** Structured JSON. JSON is natively parsed by Splunk HEC, Datadog, Cloudwatch Logs Insights, and Loki without custom extraction rules. Do not use plain-text appenders in non-local environments.
- **Trace correlation:** OpenTelemetry Java agent (default). Attach via JVM `-javaagent` flag -- no code changes required. The agent injects `trace_id` and `span_id` into MDC on every request thread automatically, including across async boundaries for common executors. If the agent cannot be used (constrained environment, Lambda cold-start sensitivity), fall back to the manual `TraceIdFilter` described below.

## Log output separation

Two distinct log outputs, each with its own file and appender:

| Log | What it captures | File |
|-----|-----------------|------|
| **Access log** | HTTP layer -- every inbound request/response (method, URI, status, duration, remote IP) | `logs/access.log` |
| **Application log** | Everything else -- service logic, errors, DB calls, external calls | `logs/app.log` |

Never mix access and application events into the same file.

### Access log pattern (Tomcat/embedded)

Configure in `application.properties`:

```properties
server.tomcat.accesslog.enabled=true
server.tomcat.accesslog.directory=logs
server.tomcat.accesslog.prefix=access
server.tomcat.accesslog.suffix=.log
server.tomcat.accesslog.rotate=true
server.tomcat.accesslog.pattern=time=%t remote_ip=%h request_method=%m url_path="%U" query_string="%q" response_code=%s time_millis=%{msec}T bytes_sent=%b Referrer="%{Referer}i" UserAgent="%{User-Agent}i" traceId=%{X-Trace-Id}i
```

A sample line:

```
time=[20/Apr/2026:10:23:01 +0000] remote_ip=192.168.1.42 request_method=POST url_path="/api/checkout" query_string="" response_code=201 time_millis=342 bytes_sent=892 Referrer="-" UserAgent="Mozilla/5.0 ..." traceId=f4a2c891-3b1d
```

Include `traceId` at the end so HTTP-layer logs can be joined to application logs in Splunk with a single field.

## Trace correlation

### Default: OpenTelemetry Java agent

Attach the Splunk Distribution of OpenTelemetry Java (or upstream `opentelemetry-javaagent.jar`) via the JVM flag. For environment-specific setup instructions see:

- **Local dev + Docker:** `java-springboot` skill -- "OTEL agent setup" section
- **AWS (EC2 / ECS):** `terraform` skill -- "Step 4a: OTEL agent on EC2" section

```
-javaagent:/opt/otel/opentelemetry-javaagent.jar
```

Set the minimum required env vars:

```
OTEL_SERVICE_NAME=my-service
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
OTEL_LOGS_EXPORTER=otlp
```

The agent injects `trace_id` and `span_id` into MDC on every request thread. Every `logger.info`, `logger.error`, etc. on that thread picks them up automatically -- no code changes required. Both fields appear in every JSON log line and correlate directly to spans in Splunk APM.

**Async threads:** the agent propagates context automatically for `ExecutorService`, `CompletableFuture`, Spring `@Async`, and most common thread pools. If you use a custom executor, wrap it:

```java
ExecutorService executor = Context.taskWrapping(Executors.newFixedThreadPool(4));
```

The frontend still sends `X-Trace-Id` to correlate browser-side events. The OTEL agent picks this up automatically if `X-Trace-Id` is mapped to the W3C `traceparent` header. Otherwise echo it back in the response header for FE log joining -- the OTEL `trace_id` is the authoritative correlation field in Splunk.

### Fallback: manual TraceIdFilter + MDC

Use only when the OTEL agent cannot be attached (Lambda cold-start constraints, locked-down infra). This gives single-service log correlation only -- no distributed tracing across services.

```java
public class TraceIdFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) {
        String traceId = Optional
            .ofNullable(((HttpServletRequest) req).getHeader("X-Trace-Id"))
            .orElse(UUID.randomUUID().toString());
        MDC.put("traceId", traceId);
        ((HttpServletResponse) res).setHeader("X-Trace-Id", traceId);
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.clear(); // always clear -- thread pool reuse
        }
    }
}
```

When using the fallback, `MDC.clear()` must always run in a `finally` block and async context propagation must be handled manually.

## Structured JSON format

Every application log line must be valid JSON with at least these fields:

```json
{
  "timestamp": "2026-04-20T10:23:01.456Z",
  "level": "INFO",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "logger": "com.example.order.OrderService",
  "message": "order_created orderId=ORD-9981 customerId=C-42 amount=149.99",
  "thread": "http-nio-8080-exec-3"
}
```

`trace_id` and `span_id` are injected by the OTEL agent -- do not set them manually. Use `logstash-logback-encoder` (Logback) or `log4j2-ecs-layout` (Log4j2) to emit JSON; both pick up MDC fields automatically.

When using the manual fallback, the field is `traceId` (camelCase, UUID format) -- note that this will not correlate to Splunk APM spans.

## Splunk / Datadog key-value pairs in message

Within the `message` field, use `key=value` pairs for structured data. This lets Splunk `rex` and Datadog attribute extraction work without JSON path queries:

```java
log.info("order_created orderId={} customerId={} amount={}", order.getId(), order.getCustomerId(), order.getAmount());
// → "message": "order_created orderId=ORD-9981 customerId=C-42 amount=149.99"
```

Rules:
- Lead with an **event name** in `snake_case` (e.g. `order_created`, `payment_failed`, `user_login`).
- Follow with `key=value` pairs for all relevant context.
- No free-form prose in structured log lines -- parsers rely on predictable tokens.

## Log levels

| Level | When to use |
|-------|-------------|
| `ERROR` | Unhandled exceptions, system failures, data integrity violations. Always include the exception object AND the entity IDs / operation context needed to reproduce the failure (e.g. `orderId`, `userId`, the action being attempted). |
| `WARN` | Recoverable issues, degraded behavior, retries, unexpected but non-fatal state. |
| `INFO` | Business touchpoints (see layer guidance below). Default production level. |
| `DEBUG` | Developer detail: SQL, serialized payloads, branch decisions. Off in production. |
| `TRACE` | Loop internals, raw bytes. Never enabled outside local dev. |

Environment defaults: `INFO` in staging/prod, `DEBUG` in local dev only.

## Per-layer logging (what to log and where)

### Controller layer

Log at the boundary -- request in, response out.

```java
log.info("request_received method={} uri={} remoteIp={}", request.getMethod(), request.getRequestURI(), request.getRemoteAddr());
// ... handle ...
log.info("request_completed status={} durationMs={}", status, duration);
```

Log `WARN` on 4xx, `ERROR` on 5xx (with exception).

### Service layer

Log business operations -- not every line, but every meaningful state transition.

```java
log.info("order_processing orderId={} stage=validation", orderId);
log.info("order_processing orderId={} stage=payment_authorized paymentRef={}", orderId, paymentRef);
log.info("order_created orderId={} customerId={}", orderId, customerId);
```

### Repository / data layer

Log query intent at `DEBUG`, never log result sets or row counts at `INFO` (volume).

```java
log.debug("db_query table=orders filter=customerId:{} limit={}", customerId, limit);
// On failure -- include the entity context so the error is self-contained:
log.error("db_query_failed table=orders customerId={} limit={}", customerId, limit, ex);
```

The exception is always the last argument to SLF4J -- Logback writes the full stack trace automatically. Include the same key=value context as the DEBUG line so you can reconstruct what was being queried without needing the preceding log line.

### Auth layer

Log at the security filter / middleware boundary. Never log credentials, tokens, or passwords at any level.

```java
// Successful authentication -- DEBUG to avoid INFO noise in high-traffic APIs
log.debug("auth_success userId={} method=jwt", userId);

// Failed authentication (bad credentials, expired token, malformed header) -- WARN
log.warn("auth_failed reason={} remoteIp={}", reason, remoteIp);
// reason values: "token_expired", "token_invalid", "token_missing", "credentials_invalid"

// Authorization denial (authenticated but not permitted) -- WARN
log.warn("authz_denied userId={} resource={} action={}", userId, resource, action);
```

Rules:
- `reason` must be a stable enum-like token, not a free-form message -- parsers and dashboards depend on it.
- Never include the token, password, or credential value in any log line, even masked/truncated.
- Log the remote IP on auth failures -- it is the primary signal for brute-force detection.
- Auth failures are WARN, not ERROR. They are expected events (wrong password, expired session); ERROR is reserved for system failures in the auth layer (e.g. the token-signing key is unavailable).

### External service calls

Log every outbound call with intent, target, and outcome:

```java
log.info("external_call service=payment-gateway action=charge amount={}", amount);
log.info("external_call_complete service=payment-gateway action=charge status={} durationMs={}", status, duration);
```

Log `ERROR` on non-2xx responses or timeouts, with response status and body excerpt (truncated to 500 chars max).

## Hard constraints

- **Never log PII.** No email addresses, names, passwords, tokens, card numbers, SSNs in any log at any level.
- **Never log secrets.** No API keys, DB credentials, JWT payloads.
- **Never log full request/response bodies** unless behind a `TRACE` guard and explicitly opt-in per endpoint.
- When using the OTEL agent, do not manually call `MDC.put("trace_id", ...)` or `MDC.clear()` -- the agent owns MDC lifecycle. Interfering with it causes context corruption.
- When using the manual fallback, `MDC.clear()` must always run in a `finally` block -- failure to clear leaks context across thread pool reuse.
- Do not construct log strings with `+` concatenation. Use SLF4J parameterized logging (`{}`) to avoid string allocation when the level is disabled.

## When to apply

Load `logging-checklist.md` before declaring any backend logging implementation complete -- new endpoints, new service layers, or changes to existing logging config. Items that genuinely do not apply must be noted as out of scope, not silently skipped. EM verifies the checklist was run during PR approval.
