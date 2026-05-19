# DB Schema Review Checklist

Run through every applicable item before declaring a schema change complete.

## Table design

- [ ] Every table has `id`, `created_at`, `updated_at` audit columns
- [ ] Soft-delete tables include `deleted_at` (nullable); hard-delete tables omit it
- [ ] Column nullability is explicit and intentional -- no accidental `NOT NULL` or nullable
- [ ] No multi-purpose columns (e.g. a `data` JSON blob hiding real structure)

## Constraints

- [ ] Foreign keys are declared for all relationships
- [ ] Unique constraints are in place where uniqueness is a business rule
- [ ] Check constraints used for bounded value sets (e.g. status enums)
- [ ] No orphaned FK references (referenced tables exist and are in schema order)

## Indexes

- [ ] Every FK column has an index (prevents full-table scans on joins)
- [ ] Columns used in `WHERE`, `ORDER BY`, or `GROUP BY` hot paths are indexed
- [ ] Index names follow `idx_{table}_{column}` / `uq_{table}_{column}` conventions
- [ ] No redundant indexes (subset covered by a composite index)

## Migrations

- [ ] Migration is additive only -- no drops or renames alongside feature changes
- [ ] Migration filename follows `YYYYMMDD_HHMMSS_<description>.sql`
- [ ] Migration is idempotent or the migration tool guarantees single-run semantics
- [ ] No data migration mixed into a DDL migration (keep them separate)
- [ ] Rollback path considered -- if the migration is irreversible, it is documented

## ER diagram

- [ ] `src/db/er-diagram.md` updated in the same commit as this schema change (required by `db-schema-change-rule.md`)

## Breaking changes

- [ ] No column removed or renamed without a deprecation migration first
- [ ] No type change that narrows the domain (e.g. `text` → `varchar(50)`) without data audit
- [ ] No NOT NULL added to an existing column without a default or backfill migration

## Security

- [ ] No PII stored in plaintext (encrypt or hash at rest)
- [ ] Sensitive columns (passwords, tokens) are not `varchar` -- use appropriate types or store only hashes
