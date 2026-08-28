# Foundation Phase 2 — Batch 1: Atomicity Verification Report (execution held)

Batch 1 was NOT executed. The approved SQL is unchanged. Option A (explicit `BEGIN`/`COMMIT` wrapper) is withdrawn — your objection is correct: PostgreSQL has no nested transactions, and a `COMMIT` inside a runner-owned transaction can close that transaction early and corrupt migration-history bookkeeping.

## Preflight (read-only) — PASSED, unchanged

Catalog query returned zero rows: no `private` schema, no `public.organizations` / `business_units` / `profiles`, no `private.set_updated_at()` / `private.handle_new_auth_user()`, no `profiles_set_updated_at` / `on_auth_user_created` trigger, and no other user tables or views in `public`. No conflicts with the strict `CREATE` statements.

## Atomicity verification — NOT ESTABLISHED

Neither guarantee A nor guarantee B can be confirmed.

What was actually inspected:

- The project repository. It contains only `supabase/config.toml`; there is no `supabase/migrations/` directory, no migration runner code, no CLI wrapper and no npm script that applies migrations. Nothing in the checked-out project defines or executes the migration.
- The migration tool contract exposed to me. It accepts a SQL string plus a description and returns a single applied/failed result. Its documented contract says nothing about PostgreSQL transaction boundaries, wire protocol, statement splitting, or where migration-history recording happens.
- Direct database access. The `PG*`-based path is read-only (select/insert), so it cannot be used to observe the runner, and observing the runner's own session behaviour is not possible after the fact.

Answers to your specific questions:

- **Model A or B in use:** cannot be determined. The runner is a platform-side service; its implementation is not present in this project and is not exposed to me.
- **Concrete evidence:** none that meets your bar. Everything available is of the "one submission, one result" class, which you have correctly ruled out as insufficient.
- **Migration-history recording inside the same transaction:** unknown.
- **Statements split and individually committed:** unknown. I cannot rule it out.
- **Simple-query vs extended-query protocol:** unknown; not exposed.

Per your instruction, this is a STOP condition. No execution.

## Options to resolve (your call)

**Option 1 — Platform confirmation.** Obtain the transaction contract for the Lovable/Supabase migration runner from the platform side (docs or support) and record it as a project decision. If it states A or B, Batch 1 executes as-is with no SQL change.

**Option 2 — Empirical probe migration (state-changing, throwaway).** Apply one disposable probe migration containing two statements where the second is guaranteed to fail, e.g. create a table `public._atomicity_probe` then `SELECT 1/0`. Then read the catalog: if `_atomicity_probe` does not exist, the runner rolled the whole file back and guarantee B holds; if it exists, the runner is non-atomic and the object is dropped in a second cleanup migration. This proves the behaviour empirically without touching Batch 1 SQL, at the cost of two throwaway migrations in history. Requires your explicit approval because it writes to the database.

**Option 3 — Accept non-atomic execution explicitly.** Execute the approved SQL unchanged, accepting that a mid-file failure could leave partial objects. The preflight shows a completely empty target, so recovery is a clean, fully enumerable teardown of exactly the Batch 1 object list. Requires you to accept the partial-state risk in writing.

**Option 4 — Continue holding.** No execution until Option 1 or 2 resolves the question.

## Unchanged scope reminder

When execution is authorised, Batch 1 creates only: schema `private`; `private.set_updated_at()` and `private.handle_new_auth_user()`; `public.organizations`, `public.business_units`, `public.profiles`; triggers `profiles_set_updated_at` and `on_auth_user_created`; the approved constraints; only the indexes `organizations_pkey`, `business_units_pkey`, `business_units_org_code_key`, `profiles_pkey`, partial `profiles_employee_code_key`; and the full lockdown (RLS on, zero policies, no `anon`/`authenticated`/`PUBLIC` privileges, no `private` USAGE for `anon`/`authenticated`, no function EXECUTE for `PUBLIC`/`anon`/`authenticated`, `service_role` server-side privileges). The approved `profiles.id → auth.users(id) ON DELETE CASCADE` stays exactly as approved. No seeds, no test users, no Batch 2, no application changes.
