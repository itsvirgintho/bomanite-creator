# Foundation Phase 2 — Batch 1: Create versioned Supabase migration file

## Objective
Create exactly one timestamped Supabase migration file in the repository containing the approved Batch 1 SQL, with no semantic changes and no remote database execution.

## File to create
`supabase/migrations/<timestamp>_foundation_phase2_batch1_core.sql`

where `<timestamp>` is the current UTC timestamp in Supabase migration format `YYYYMMDDHHMMSS`.

## Directory to create (if absent)
`supabase/migrations/`

## Contents
The file will contain the approved Batch 1 SQL exactly as frozen in the previous plan, including:

- `CREATE SCHEMA private;` and privilege revocation on it.
- `CREATE FUNCTION private.set_updated_at();` (non-security definer, `search_path=''`).
- Tables:
  - `public.organizations`
  - `public.business_units`
  - `public.profiles`
- FKs:
  - `business_units.organization_id → organizations.id ON DELETE RESTRICT`
  - `profiles.id → auth.users.id ON DELETE CASCADE`
- Triggers:
  - `profiles_set_updated_at` on `public.profiles`
  - `on_auth_user_created` on `auth.users`
- Function `private.handle_new_auth_user()` (security definer, `search_path=''`).
- Indexes:
  - PK indexes (created automatically by PK constraints)
  - `business_units_org_code_key` via `UNIQUE (organization_id, code)`
  - partial unique index `profiles_employee_code_key` where `employee_code IS NOT NULL`
- Security lockdown:
  - RLS enabled immediately on all three tables
  - Zero policies
  - No table privileges for `anon`, `authenticated`, or `PUBLIC`
  - No `USAGE` on schema `private` for `anon`/`authenticated`
  - No `EXECUTE` on `private.set_updated_at()` or `private.handle_new_auth_user()` for `PUBLIC`/`anon`/`authenticated`
  - `service_role` granted `ALL` on the three tables

## What will NOT be in the file
- `BEGIN` / `COMMIT`
- `IF NOT EXISTS`
- `CREATE OR REPLACE`
- Seed data, users, roles, permissions, projects, financial tables, locations, audit, Superadmin helpers, additional indexes/policies
- Pipeline-incompatible statements (`CREATE INDEX CONCURRENTLY`, `REINDEX`, `VACUUM`, `ALTER SYSTEM`, `CLUSTER`)

## What will NOT happen
- No `supabase db push`
- No `supabase db reset --linked`
- No remote migration tool
- No SQL execution against the Supabase project
- No modification to `supabase/config.toml` unless a migration-directory config change is strictly required
- No other repository files changed
- No Auth users or seed rows created

## Deliverables after creation
- Exact migration filename
- Confirmation that contents are byte-equivalent in SQL semantics to the approved Batch 1
- Confirmation that `supabase/config.toml` is unchanged
- Confirmation that no other repository files were changed
- Confirmation that no database calls were made
- Confirmation that no migration was recorded remotely
