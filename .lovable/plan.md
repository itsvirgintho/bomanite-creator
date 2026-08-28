# Foundation Phase 2 — Migration Batch 1: Preflight Result and Execution Decision

## 1. Preflight (read-only) — PASSED

Queried live database metadata (`pg_namespace`, `pg_class`, `pg_proc`, `pg_trigger`). Result: **zero rows**.

Confirmed absent (no conflicts with the strict `CREATE` statements):

- Schema `private` — does not exist
- `public.organizations` — does not exist
- `public.business_units` — does not exist
- `public.profiles` — does not exist
- `private.set_updated_at()` — does not exist
- `private.handle_new_auth_user()` — does not exist
- Trigger `profiles_set_updated_at` — does not exist
- Trigger `on_auth_user_created` on `auth.users` — does not exist
- No other user tables/views exist in `public` at all

Nothing must be dropped, replaced or reused. Batch 1 can be created cleanly.

## 2. Atomicity verification — the one open blocker

Requirement: execute as-is only if the migration mechanism guarantees the whole file runs inside one PostgreSQL transaction.

What is established:

- Migrations are applied through the platform migration tool, which submits the approved SQL as a single versioned migration and reports one success/failure result.
- What cannot be established from inside this environment, with confidence, is whether that single submission is wrapped by the runner in one explicit `BEGIN/COMMIT`. A multi-statement submission is not automatically transactional, exactly as stated in the approval.

Per the approval instructions this is a STOP condition, so Batch 1 was **not** executed in this turn.

## 3. Resolution options (pick one)

**Option A — Explicit transaction wrapper (recommended).**
Submit the approved Batch 1 SQL unchanged, wrapped in a leading `BEGIN;` and a trailing `COMMIT;`. This is migration-framework syntax only and changes no database semantics: every object, constraint, index, grant/revoke and trigger stays byte-identical. It is safe in both cases — if the runner already opens a transaction, the extra `BEGIN` is a no-op warning and the `COMMIT` still commits the full batch; if it does not, the wrapper supplies the required all-or-nothing guarantee. Partial application becomes impossible either way.

**Option B — Execute as-is.**
Submit the approved SQL with no wrapper, accepting the residual risk that a failure mid-batch could leave partially created objects. Because the preflight shows a completely empty target, recovery would be a clean manual teardown of whatever was created, but it is still a partial-state risk.

**Option C — Hold.**
Do not execute; keep the frozen SQL pending an out-of-band confirmation of runner transaction semantics.

## 4. What happens on approval

1. Create exactly one versioned migration containing only: schema `private`; functions `private.set_updated_at()` and `private.handle_new_auth_user()`; tables `public.organizations`, `public.business_units`, `public.profiles`; triggers `profiles_set_updated_at` and `on_auth_user_created`; the approved constraints, the approved indexes only (`organizations_pkey`, `business_units_pkey`, `business_units_org_code_key`, `profiles_pkey`, partial `profiles_employee_code_key`), and the full security lockdown.
2. FKs exactly as approved: `business_units.organization_id → organizations.id ON DELETE RESTRICT`; `profiles.id → auth.users.id ON DELETE CASCADE` (retained — this is the approved intentional cascade, not a destructive CASCADE operation).
3. Post-execution validation against real catalog metadata: object existence; columns/types/defaults/nullability; FK delete rules; exact index list with no extra `organizations_active_idx` or standalone `business_units.organization_id` index; RLS enabled on all three with zero policies; no privileges for `anon`, `authenticated` or `PUBLIC` on the three tables, no `private` schema `USAGE` for `anon`/`authenticated`, no function `EXECUTE` for `PUBLIC`/`anon`/`authenticated`, `service_role` privileges present; zero rows in all three tables.
4. Confirm no Batch 2 objects, no helpers, no seed data, no Auth users, no frontend/mock-data changes. The only intentional `auth` change is the `on_auth_user_created` trigger.
5. Then STOP — no test users, no Batch 2.

## 5. Out of scope for this batch

Roles, permissions, `role_permissions`, memberships, permission overrides, projects, `project_locations`, financial tables, `audit_logs`, `platform_admins`, RLS/access helper functions, navigation, frontend code, seed/business rows, Auth users.
