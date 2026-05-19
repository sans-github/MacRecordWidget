---
name: db-schema
description: Database schema, migration, and seed conventions. Use when adding a DB layer, creating the initial schema, writing migration scripts, or seeding initial data.
---

# DB Schema and Migrations

## Directory structure

```
db/
├── schema/       # baseline table definitions, loaded once
├── migrations/   # additive changes after initial setup
└── seeds/
    ├── common/   # config/reference data, runs in all environments
    └── dev/      # fixture data, runs only in dev/staging
```

---

## Schema files (one-time setup)

Schema files define the baseline structure. They run once to create the initial tables, indexes, and constraints. **Never modify them after first run** -- all subsequent changes go through migrations.

Files are numbered to enforce load order (important when tables reference each other via foreign keys):

```
src/db/schema/
├── 01_users.sql
├── 02_roles.sql
├── 03_orders.sql
```

Use sequential numbers, not timestamps. The schema is a fixed baseline, not an evolving history.

---

## Migration scripts (additive changes)

Every schema change after initial setup is a migration. Migrations are:

- **Additive only** -- add columns, tables, indexes. Never drop or rename in the same script as a feature change
- **Never edited after merge** -- if a migration is wrong, write a new one to correct it
- **Run once per environment** -- the migration tool tracks which scripts have run and skips them on subsequent app starts

### File naming

```
YYYYMMDD_HHMMSS_<description>.sql
```

Examples:
```
src/db/migrations/
├── 20240315_143022_add_email_index_to_users.sql
├── 20240316_091500_add_phone_to_users.sql
```

The timestamp ensures global ordering and avoids conflicts when multiple branches introduce migrations simultaneously.

---

## Seed files (initial data)

Seeds populate configuration or reference data the system needs to operate. Like schema files, they are numbered and run once -- the migration tool tracks them separately so they are not re-applied on subsequent starts.

```
src/db/seeds/
├── 01_config_settings.sql
├── 02_lookup_codes.sql
```

Seeds are split by environment:

- `src/db/seeds/common/` -- config and reference data the system needs to operate in every environment (e.g. permission types, status codes, default settings). Always runs.
- `src/db/seeds/dev/` -- richer fixture data for local development and staging (e.g. sample users, demo content). **Never runs in production.**

The app (or migration tool) determines which folders to apply based on the current environment. Production applies `common/` only.

---

## App startup order

1. Run any pending schema files (in numeric order)
2. Run any pending seed files (in numeric order)
3. Run any pending migration files (in timestamp order)

Use a dedicated migration tool -- do not hand-roll the tracking logic:

| Ecosystem | Tool |
|-----------|------|
| JVM | Flyway, Liquibase |
| Python | Alembic, Yoyo |
| Node | node-pg-migrate, Knex, Prisma Migrate |
| Go | Goose, golang-migrate |
| Ruby | Active Record Migrations |

---

## Migration tool configuration

This project uses a split directory layout that most tools do not assume by default. Configure your tool to discover all three locations in order:

1. `src/db/schema/` -- baseline table definitions (run first)
2. `src/db/seeds/common/` -- reference data safe for all environments
3. `src/db/migrations/` -- incremental changes

`src/db/seeds/dev/` is only for dev/staging. Never include it in a prod profile.

The migration tool uses the portion before the first separator character as the version key -- so it knows which scripts have already been applied and skips them. File naming examples: `01_users.sql` (version `01`), `20240315143022_add_phone.sql` (version `20240315143022`).

---

## ORM and DDL settings

The migration tool owns all schema creation. The ORM must never create or modify tables -- disable any ORM-managed DDL in every environment (dev, test, prod). Examples by stack:

| Stack | Setting |
|-------|---------|
| Spring Boot / Hibernate | `spring.jpa.hibernate.ddl-auto=validate` |
| Django | `MIGRATION_MODULES` -- never run `syncdb` or `migrate --run-syncdb` outside of migrations |
| Sequelize / TypeORM | `sync: false` / `synchronize: false` |
| Prisma | Use `prisma migrate deploy`, never `db push` in production |

If the ORM reports a missing table or column, the fix is always to write a migration -- never to re-enable DDL generation.

Startup sequence -- the migration tool runs before the ORM validates or connects:
1. Migration tool applies any pending scripts
2. ORM validates the schema (if validation is supported)
3. Application starts

Responsibility split:
- The BE agent writes all schema files (`src/db/schema/`) and migration files (`src/db/migrations/`) as part of implementation.
- The human only creates the database and user (as documented in the README). Schema structure is never a manual human task.

---

## Standard audit columns

Every table should include these columns unless there is a specific reason not to:

| Column | Type | Purpose |
|--------|------|---------|
| `id` | UUID, primary key | surrogate key -- never auto-increment |
| `created_at` | timestamp with timezone | set on insert, never updated |
| `updated_at` | timestamp with timezone | updated on every write |
| `deleted_at` | timestamp with timezone (nullable) | soft delete -- null means active |

`deleted_at` is optional. If the system uses hard deletes, omit it. If soft deletes are used, all queries must filter `WHERE deleted_at IS NULL` by default.

Define these as part of the initial schema so they are consistent across all tables from the start.

---

## Resources

- Load `db-checklist.md` before declaring any schema change complete. Items that genuinely do not apply must be noted as out of scope, not silently skipped. EM verifies the checklist was run during schema approval.

---

## Column naming

All column names use snake_case (e.g. `created_at`, `user_id`, `order_total`). Never camelCase or PascalCase.

## Foreign key naming

Default: `{referenced_table}_id` (e.g. `user_id` references `users.id`, `order_id` references `orders.id`).

Exception: when a table has two FKs pointing to the same table, use role-based naming that makes the relationship intent clear:

```sql
-- Two FKs to users -- use role-based names
ALTER TABLE orders ADD COLUMN customer_id UUID NOT NULL REFERENCES users(id);
ALTER TABLE orders ADD COLUMN shipping_contact_id UUID REFERENCES users(id);
```

Never use ambiguous names like `user_id_1` / `user_id_2`.

---

## Index naming

Use a consistent naming pattern so indexes are predictable and searchable:

```
idx_{table}_{column(s)}
```

Examples:
```sql
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_orders_user_id_created_at ON orders (user_id, created_at);
```

For unique indexes:
```
uq_{table}_{column(s)}
```

Example:
```sql
CREATE UNIQUE INDEX uq_users_email ON users (email);
```
