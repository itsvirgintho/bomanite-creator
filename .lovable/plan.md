# Foundation Phase 2 — Migration Batch 1 (SQL PROPOSAL, not executed)

Scope: `private` schema, reusable `updated_at` trigger function, `organizations`, `business_units`, `profiles`, the auth→profile shell trigger, and immediate lockdown. No RBAC, no projects, no helpers, no seeds, no app changes.

## 1. Design decisions

- **`private` schema now, empty of authorization logic.** Created in Batch 1 only so the reusable trigger function has a non-exposed home. No `USAGE` to `anon`/`authenticated` in this batch — nothing here is called from a policy yet.
- **`updated_at` function is NOT SECURITY DEFINER.** It only rewrites `NEW.updated_at` inside the row being written; it needs no elevated privilege. Triggers execute regardless of the caller's EXECUTE privilege, so `EXECUTE` is revoked from `PUBLIC`, `anon`, `authenticated`. It is generic (`set updated_at = now()`) and reusable by every future table.
- **`first_name` / `last_name` are NULLABLE.** Users are created manually in the Supabase Auth Dashboard, which sends no `raw_user_meta_data`. A `NOT NULL` column would make the AFTER INSERT trigger raise and **Auth user creation itself would fail**. The profile is a *shell*: identity completeness (names, employee_code, job_title) is filled later by the reviewed bootstrap/admin process. `is_active` defaults to `true` but grants nothing — authorization comes from membership tables in later batches.
- **The handle-new-user function is SECURITY DEFINER** — required, because the trigger runs in the `auth` insert context and must write to `public.profiles` regardless of the inserting role. It is unreachable as an API: `private` is not an exposed Data API schema, `EXECUTE` is revoked from `PUBLIC`/`anon`/`authenticated`, it takes no arguments, returns `trigger` (so it cannot be called as a normal function at all), and it derives the id from `NEW.id` only — a caller could never pass a target user id.
- **Trigger is deliberately minimal** — one INSERT, `ON CONFLICT (id) DO NOTHING`, no memberships, no roles, no lookups. Nothing in it can block Auth signup other than a catastrophic DB failure.
- **Identity is the UUID, never the email.** No email column on `profiles`.
- **Delete behavior:** `profiles.id → auth.users(id) ON DELETE CASCADE` (profile shell only, per approved architecture). `business_units.organization_id → organizations(id) ON DELETE RESTRICT` — business history must survive; organizations are deactivated (`is_active = false`), not deleted.
- **Lockdown first.** RLS is enabled on all three tables in the same migration that creates them, with **no policies at all**. Even if Batch 1 shipped alone, RLS-enabled + no policy = zero rows for `anon` and `authenticated`, and grants are revoked on top of that (defense in depth).
- **No index beyond what PK/UNIQUE already create**, plus one FK index on `business_units.organization_id` (Postgres does not create it automatically and every join/cascade check uses it) and one partial index on active organizations. Nothing else — the database is empty.

## 2. Proposed SQL

```sql
-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 1
-- Core schema foundation: private schema, organizations,
-- business_units, profiles, auth->profile shell trigger, lockdown.
-- No RBAC, no projects, no seed data.
-- ============================================================

-- ---------- 1. private schema ----------
CREATE SCHEMA IF NOT EXISTS private;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
-- No USAGE granted in Batch 1. Policy helpers arrive in a later batch
-- and will each receive an individual USAGE + EXECUTE grant.

-- ---------- 2. reusable updated_at trigger function ----------
CREATE OR REPLACE FUNCTION private.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.set_updated_at() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.set_updated_at() FROM anon;
REVOKE ALL ON FUNCTION private.set_updated_at() FROM authenticated;
-- Not SECURITY DEFINER: it needs no elevated privilege.
-- Triggers fire regardless of the caller's EXECUTE privilege.

-- ---------- 3. public.organizations ----------
CREATE TABLE public.organizations (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text        NOT NULL,
  legal_name        text        NOT NULL,
  tax_id            text        NULL,
  country           text        NOT NULL DEFAULT 'MX',
  timezone          text        NOT NULL DEFAULT 'America/Mazatlan',
  default_currency  text        NOT NULL DEFAULT 'MXN',
  is_active         boolean     NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT organizations_name_not_blank
    CHECK (length(btrim(name)) > 0),
  CONSTRAINT organizations_legal_name_not_blank
    CHECK (length(btrim(legal_name)) > 0),
  CONSTRAINT organizations_country_iso2
    CHECK (country ~ '^[A-Z]{2}$'),
  CONSTRAINT organizations_currency_iso3
    CHECK (default_currency ~ '^[A-Z]{3}$'),
  CONSTRAINT organizations_timezone_not_blank
    CHECK (length(btrim(timezone)) > 0)
);

CREATE INDEX organizations_active_idx
  ON public.organizations (id) WHERE is_active;

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.organizations FROM PUBLIC;
REVOKE ALL ON TABLE public.organizations FROM anon;
REVOKE ALL ON TABLE public.organizations FROM authenticated;
GRANT ALL ON TABLE public.organizations TO service_role;
-- No policies in Batch 1: RLS on + zero policies = zero rows for
-- anon/authenticated even if a grant were ever added by accident.

-- ---------- 4. public.business_units ----------
CREATE TABLE public.business_units (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid        NOT NULL
                   REFERENCES public.organizations (id) ON DELETE RESTRICT,
  name             text        NOT NULL,
  code             text        NOT NULL,
  is_active        boolean     NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_units_org_code_key UNIQUE (organization_id, code),
  CONSTRAINT business_units_name_not_blank
    CHECK (length(btrim(name)) > 0),
  CONSTRAINT business_units_code_format
    CHECK (code ~ '^[A-Z0-9][A-Z0-9_-]{0,31}$')
);

CREATE INDEX business_units_organization_id_idx
  ON public.business_units (organization_id);

ALTER TABLE public.business_units ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.business_units FROM PUBLIC;
REVOKE ALL ON TABLE public.business_units FROM anon;
REVOKE ALL ON TABLE public.business_units FROM authenticated;
GRANT ALL ON TABLE public.business_units TO service_role;

-- ---------- 5. public.profiles ----------
CREATE TABLE public.profiles (
  id             uuid        PRIMARY KEY
                 REFERENCES auth.users (id) ON DELETE CASCADE,
  first_name     text        NULL,
  last_name      text        NULL,
  phone          text        NULL,
  avatar_path    text        NULL,
  job_title      text        NULL,
  employee_code  text        NULL,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_employee_code_format
    CHECK (employee_code IS NULL OR length(btrim(employee_code)) > 0),
  CONSTRAINT profiles_phone_format
    CHECK (phone IS NULL OR length(btrim(phone)) > 0)
);

-- employee_code must be unique when present, but is optional at shell creation.
CREATE UNIQUE INDEX profiles_employee_code_key
  ON public.profiles (employee_code) WHERE employee_code IS NOT NULL;

CREATE TRIGGER profiles_set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.profiles FROM PUBLIC;
REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;

-- ---------- 6. auth.users -> profile shell ----------
CREATE OR REPLACE FUNCTION private.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name)
  VALUES (
    NEW.id,
    nullif(btrim(coalesce(NEW.raw_user_meta_data ->> 'first_name', '')), ''),
    nullif(btrim(coalesce(NEW.raw_user_meta_data ->> 'last_name',  '')), '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM anon;
REVOKE ALL ON FUNCTION private.handle_new_auth_user() FROM authenticated;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION private.handle_new_auth_user();
```

## 3. Section-by-section explanation

1. **`private` schema** — non-exposed namespace. Not added to the Data API exposed schemas (that setting stays `public` only). No `USAGE` yet, deliberately.
2. **`private.set_updated_at()`** — generic, table-agnostic, plpgsql, `search_path = ''`, no relations referenced so nothing to qualify. Touches only `NEW.updated_at`; never authorization fields, actor identity or business fields.
3. **`organizations`** — `gen_random_uuid()` PK (pgcrypto is built into Supabase). `tax_id` nullable (foreign/unregistered entities). Defaults `MX` / `America/Mazatlan` / `MXN` match DFN reality and keep future inserts safe. Format CHECKs are cheap and immutable (no `now()` in CHECKs). Partial index on active orgs; no other index on an empty table.
4. **`business_units`** — `UNIQUE (organization_id, code)` as required; explicit FK index because Postgres does not create one and `ON DELETE RESTRICT` checks use it. `RESTRICT` protects business history.
5. **`profiles`** — id is both PK and FK to `auth.users` with `ON DELETE CASCADE` (shell row only). No email, no password, no role, no organization_id, no financial level. `employee_code` unique only when present, via a partial unique index so many shells with NULL coexist.
6. **Auth trigger** — `AFTER INSERT ... FOR EACH ROW`, reads metadata defensively (missing keys yield NULL, blank strings normalize to NULL), `ON CONFLICT DO NOTHING` so a re-created id or a manual pre-seeded profile never raises.

## 4. Exact objects created

Schema `private`. Functions `private.set_updated_at()`, `private.handle_new_auth_user()`. Tables `public.organizations`, `public.business_units`, `public.profiles`. Triggers `profiles_set_updated_at` (on `public.profiles`), `on_auth_user_created` (on `auth.users`). Indexes: 3 PK indexes, `business_units_org_code_key`, `organizations_active_idx`, `business_units_organization_id_idx`, `profiles_employee_code_key`.

Nothing else is altered. No existing object is dropped or modified.

## 5. Privilege and RLS state after Batch 1

| Role | organizations | business_units | profiles | schema private |
|---|---|---|---|---|
| `anon` | none | none | none | none |
| `authenticated` | none | none | none | none (no USAGE) |
| `PUBLIC` | none | none | none | none |
| `service_role` | ALL | ALL | ALL | none needed |

RLS: **enabled on all three tables, zero policies**. Both barriers hold independently — a client would be blocked by the missing grant, and blocked again by RLS returning no rows. Function EXECUTE is revoked from `PUBLIC`/`anon`/`authenticated` on both functions; both are still invoked normally because trigger execution does not consult EXECUTE privileges.

`service_role` receives `ALL` because it is the server-side/administrative path required by the approved architecture (bootstrap script, future trusted server functions). It bypasses RLS by design and never reaches the browser.

**Separate recommendation, deliberately NOT in this SQL:** `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon, authenticated;` would make every future table locked-by-default. It is attractive but it silently changes behavior for objects Lovable tooling may create later, and it can mask a forgotten explicit grant. Recommendation: keep explicit per-table grants (as every later batch already specifies) and skip the default-privileges change unless you want it as its own reviewed migration.

## 6. Trigger behavior and failure considerations

- Dashboard-created user with no metadata → profile shell with NULL names. Signup succeeds.
- Metadata present → names copied, trimmed, blanks normalized to NULL.
- Duplicate/replayed id → `ON CONFLICT DO NOTHING`, no error.
- The function performs a single INSERT with no lookups, no joins, no FK to a table that may be empty — nothing to fail on.
- Residual risk: any exception inside an AFTER INSERT trigger on `auth.users` rolls back the Auth user creation. This is why the body is one statement and why the name columns are nullable. Optionally the INSERT could be wrapped in `EXCEPTION WHEN OTHERS THEN RETURN NEW;` to make signup unblockable, at the cost of silently missing profiles — **recommendation: do not swallow errors**; a missing profile is worse than a visible failure, and the current body has no realistic failure mode.

## 7. Security review

- No table is reachable by `anon` or `authenticated`, by grant or by policy.
- `private` is unexposed and ungranted; neither function is callable as an RPC (both return `trigger`, which PostgREST cannot invoke anyway).
- `handle_new_auth_user` cannot be abused as a mutation API: no arguments, id taken from `NEW.id`, unreachable from the client.
- No secrets, personal data, emails, passwords or environment UUIDs.
- No `DROP`, no `CASCADE`, no changes to `auth`/`storage`/`realtime`/`vault` objects other than the supported `AFTER INSERT` trigger on `auth.users`.
- Expected linter notices after this batch: "table has RLS enabled but no policies" on all three tables — intentional in Batch 1.

## 8. Rollback considerations

Forward-only. A corrective migration would drop, in order: `on_auth_user_created`, `profiles_set_updated_at`, `public.profiles`, `public.business_units`, `public.organizations`, both `private` functions, then `private` — each without `CASCADE`. Dropping the auth trigger is the single highest-priority rollback step if Auth signup ever breaks; it can be dropped alone, leaving the tables intact.

## 9. Uncertainties to confirm

1. **Timezone/currency defaults** — `America/Mazatlan` and `MXN` assumed from DFN's location. Confirm or make them explicit-required with no default.
2. **`business_units.code` format** — uppercase alnum/`_`/`-`, max 32 chars assumed (e.g. `BOMANITE_CABO`). Confirm the convention before it is seeded.
3. **`organizations.legal_name` NOT NULL** — assumed always known. Say so if some organizations may lack one.
4. **Trigger error swallowing** — recommendation is not to swallow; confirm you agree.
5. **Default privileges recommendation** — presented separately in §5; confirm whether you want it as its own later migration.

## 10. Batch 1 acceptance checklist

- [ ] `private` schema exists, not in the Data API exposed schemas, no `USAGE` to `anon`/`authenticated`.
- [ ] `private.set_updated_at()` exists, is not SECURITY DEFINER, `search_path = ''`, EXECUTE revoked from PUBLIC/anon/authenticated.
- [ ] `organizations`, `business_units`, `profiles` exist with the stated PK/FK/UNIQUE/CHECK/index set.
- [ ] `business_units` has `UNIQUE (organization_id, code)` and `ON DELETE RESTRICT` to organizations.
- [ ] `profiles.id` FKs `auth.users(id) ON DELETE CASCADE`; `first_name`/`last_name` nullable; no email/password/role/org/financial columns.
- [ ] `profiles_set_updated_at` fires on UPDATE and changes only `updated_at`.
- [ ] Creating a user in the Auth Dashboard with no metadata succeeds and produces exactly one profile shell.
- [ ] RLS enabled on all three tables with zero policies.
- [ ] `anon` and `authenticated` have no privilege on any of the three tables and cannot read a single row.
- [ ] `service_role` has `ALL` on the three tables.
- [ ] No seed rows, no personal data, no environment UUIDs, no DROP/CASCADE, no app code changes.
