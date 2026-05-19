# REST API Reference

## URL Structure

### Resource naming

```
# Good - plural nouns
GET /api/users
GET /api/orders

# Bad - verbs or inconsistent naming
GET /api/getUser
GET /api/user
POST /api/createOrder
```

### Nested resources

```
# Shallow nesting (preferred, max 2 levels)
GET /api/users/{id}/orders
GET /api/orders/{id}

# Deep nesting (avoid)
GET /api/users/{id}/orders/{orderId}/items/{itemId}/reviews
# Better:
GET /api/order-items/{id}/reviews
```

---

## HTTP Methods and Status Codes

### GET

```
GET /api/users              → 200 OK
GET /api/users/{id}         → 200 OK | 404 Not Found
GET /api/users?page=2       → 200 OK
```

### POST

```
POST /api/users
  Body: {"name": "John", "email": "john@example.com"}
  → 201 Created
  Location: /api/users/123

POST /api/users (validation error)
  → 422 Unprocessable Entity
```

### PUT

```
PUT /api/users/{id}
  Body: {all fields required}
  → 200 OK | 404 Not Found
```

### PATCH

```
PATCH /api/users/{id}
  Body: {"name": "Jane"}  (changed fields only)
  → 200 OK | 404 Not Found
```

### DELETE

```
DELETE /api/users/{id}
  → 204 No Content | 404 Not Found | 409 Conflict
```

### Status code reference

| Code | When |
|------|------|
| 200 | Successful GET, PATCH, PUT |
| 201 | Successful POST |
| 204 | Successful DELETE |
| 400 | Malformed request |
| 401 | Missing or invalid token |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | State conflict (duplicate, etc.) |
| 422 | Validation errors |
| 429 | Rate limited |
| 500 | Server error |
| 503 | Temporary downtime |

---

## Filtering, Sorting, and Searching

```
GET /api/users?status=active
GET /api/users?role=admin&status=active
GET /api/users?sort=created_at
GET /api/users?sort=-created_at        (descending)
GET /api/users?search=john
GET /api/users?fields=id,name,email    (sparse fieldsets)
```

---

## Pagination

### Offset-based (simple cases)

```
GET /api/users?page=2&page_size=20

Response:
{
  "items": [...],
  "page": 2,
  "page_size": 20,
  "total": 150,
  "pages": 8
}
```

### Cursor-based (large or fast-moving datasets)

```
GET /api/users?limit=20&cursor=eyJpZCI6MTIzfQ

Response:
{
  "items": [...],
  "next_cursor": "eyJpZCI6MTQzfQ",
  "has_more": true
}
```

### Link header (RESTful alternative)

```
Link: <https://api.example.com/users?page=3>; rel="next",
      <https://api.example.com/users?page=1>; rel="prev"
```

---

## Versioning

### URL versioning (recommended)

```
/api/v1/users
/api/v2/users
```

Pros: visible, easy to route. Cons: multiple URLs per resource.

### Header versioning

```
Accept: application/vnd.api+json; version=2
```

Pros: clean URLs. Cons: less visible, harder to test in a browser.

### Query parameter

```
GET /api/users?version=2
```

Pros: easy to test. Cons: optional param can be forgotten.

---

## Rate Limiting

Return these headers on every response:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 742
X-RateLimit-Reset: 1640000000

429 Too Many Requests
Retry-After: 3600
```

---

## Authentication and Authorization

```
# Bearer token
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

401 Unauthorized -- missing or invalid token
403 Forbidden    -- valid token, insufficient permissions

# API key
X-API-Key: your-api-key-here
```

---

## Error Response Format

All errors return the same shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format",
        "value": "not-an-email"
      }
    ],
    "timestamp": "2025-10-16T12:00:00Z",
    "path": "/api/users"
  }
}
```

---

## Caching

```
Cache-Control: public, max-age=3600          # client caching
Cache-Control: no-cache, no-store            # no caching
ETag: "33a64df551425fcc55e4d42a148795d9f25f89d4"
If-None-Match: "..."  → 304 Not Modified
```

---

## Bulk Operations

```
POST /api/users/batch
{
  "items": [
    {"name": "User1", "email": "user1@example.com"},
    {"name": "User2", "email": "user2@example.com"}
  ]
}

Response:
{
  "results": [
    {"id": "1", "status": "created"},
    {"id": null, "status": "failed", "error": "Email already exists"}
  ]
}
```

---

## Idempotency

Use an idempotency key header for non-idempotent operations that may be retried:

```
POST /api/orders
Idempotency-Key: unique-key-123

Duplicate request → 200 OK (return cached response)
```

---

## CORS

Restrict `allow_origins` to known domains in production. Never use wildcard `*` with credentials enabled.

---

## Documentation

Generate an OpenAPI spec from code (e.g. springdoc-openapi for Spring Boot). Expose `/docs` and `/redoc`. Document all endpoints, request/response shapes, error responses, and auth flow.

---

## Health Endpoints

```
GET /health          → {"status": "healthy", "version": "1.0.0"}
GET /health/detailed → per-dependency status (db, cache, external APIs)
```
