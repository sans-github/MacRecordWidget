# API Design Checklist

## Resource Design

- [ ] Resources are nouns, not verbs
- [ ] Plural names for collections
- [ ] Consistent naming across all endpoints
- [ ] Clear resource hierarchy (avoid deep nesting >2 levels)
- [ ] All CRUD operations properly mapped to HTTP methods

## HTTP Methods

- [ ] GET for retrieval (safe, idempotent)
- [ ] POST for creation
- [ ] PUT for full replacement (idempotent)
- [ ] PATCH for partial updates
- [ ] DELETE for removal (idempotent)

## Status Codes

- [ ] 200 for successful GET/PATCH/PUT
- [ ] 201 for POST
- [ ] 204 for DELETE
- [ ] 400 for malformed requests
- [ ] 401 for missing auth
- [ ] 403 for insufficient permissions
- [ ] 404 for missing resources
- [ ] 422 for validation errors
- [ ] 429 for rate limiting
- [ ] 500 for server errors

## Pagination

- [ ] All collection endpoints paginated
- [ ] Default page size defined (e.g. 20)
- [ ] Maximum page size enforced (e.g. 100)
- [ ] Pagination metadata included (total, pages, etc.)
- [ ] Cursor-based or offset-based pattern chosen consistently

## Filtering & Sorting

- [ ] Query parameters for filtering
- [ ] Sort parameter supported
- [ ] Search parameter for full-text search
- [ ] Field selection supported (sparse fieldsets)

## Versioning

- [ ] Versioning strategy defined (URL/header/query)
- [ ] Version included in all endpoints
- [ ] Deprecation policy documented

## Error Handling

- [ ] Consistent error response format across all endpoints
- [ ] Field-level validation errors included
- [ ] Error codes for programmatic client handling

## Authentication & Authorization

- [ ] Auth method defined (Bearer token, API key)
- [ ] Authorization checks on all endpoints
- [ ] 401 vs 403 used correctly
- [ ] Token expiration handled

## Rate Limiting

- [ ] Rate limits defined per endpoint/user
- [ ] Rate limit headers included in responses
- [ ] Retry-After header provided on 429

## Documentation

- [ ] OpenAPI/Swagger spec generated
- [ ] All endpoints documented with examples
- [ ] Error responses documented
- [ ] Auth flow documented

## Testing

- [ ] Integration tests for all endpoints
- [ ] Error scenarios tested
- [ ] Edge cases covered
- [ ] Performance tests for heavy endpoints

## Security

- [ ] Input validation on all fields
- [ ] SQL injection prevention
- [ ] XSS prevention
- [ ] CORS configured (no wildcard in production)
- [ ] HTTPS enforced
- [ ] Sensitive data not in URLs
- [ ] No secrets in responses

## Performance

- [ ] N+1 queries prevented
- [ ] Caching strategy defined
- [ ] Cache headers set appropriately

## Monitoring

- [ ] Request logging implemented
- [ ] Error tracking configured
- [ ] Health check endpoint available (`/health`)
