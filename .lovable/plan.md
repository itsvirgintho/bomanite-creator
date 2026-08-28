# Foundation Phase 2 — Migration Batch 1 (REVISED SQL PROPOSAL, not executed)

Corrections applied: strict versioned-migration DDL (`CREATE SCHEMA`, `CREATE FUNCTION` — no `IF NOT EXISTS`, no `OR REPLACE`), both redundant indexes removed, `ON CONFLICT DO NOTHING` removed from the profile trigger, and an explicit atomicity statement. All other approved decisions unchanged.

## 1. Revised SQL

```sql
-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 1
-- Versioned migration, not an idempotent bootstrap script.
-- Fails loudly if any same-named object already exists.
-- ============================================================

-- ---------- 1. private schema ----------
CREATE SCHEMA private;

REVOKE ALL ON SCHEMA private FROM PUBLIC;
REVOKE ALL ON SCHEMA private FROM anon;
REVOKE ALL ON SCHEMA private FROM authenticated;
-- No USAGE granted in Batch 1. Policy helpers arrive in later batches
-- and will each receive an individual USAGE + EXECUTE grant.

-- ---------- 2. reusable updated_at trigger function ----------
CREATE FUNCTION private.set_updated_at()
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
-- Trigger execution does not consult the caller's EXECUTE privilege.

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

ALTER TABLE public.business_units ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.business_units FROM PUBLIC;
REVOKE ALL ON TABLE public.business_units FROM anon;
REVOKE ALL ON TABLE public.business_units FROM authenticated;
GRANT ALL ON TABLE public.business_units TO service_role;
-- No separate FK index: the UNIQUE (organization_id, code) backing index
-- has organization_id as its leading column and covers FK lookups/joins.

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

-- Unique only when present; many shells with NULL employee_code coexist.
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
CREATE FUNCTION private.handle_new_auth_user()
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
  );
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

## 2. Exact objects and indexes created

- Schema: `private`.
- Functions: `private.set_updated_at()` (plpgsql, `search_path = ''`, NOT SECURITY DEFINER), `private.handle_new_auth_user()` (plpgsql, SECURITY DEFINER, `search_path = ''`).
- Tables: `public.organizations`, `public.business_units`, `public.profiles`.
- Triggers: `profiles_set_updated_at` (BEFORE UPDATE on `public.profiles`), `on_auth_user_created` (AFTER INSERT on `auth.users`).
- Indexes — only those automatically required:
  - `organizations_pkey` (PK), `business_units_pkey` (PK), `profiles_pkey` (PK).
  - `business_units_org_code_key` (backing index for `UNIQUE (organization_id, code)`; leading column covers organization lookups and the RESTRICT check).
  - `profiles_employee_code_key` (partial unique, only where `employee_code IS NOT NULL`).
- **Removed** (redundant): `organizations_active_idx`, `business_units_organization_id_idx`. No replacement indexes.

Nothing else is created, altered or dropped.

## 3. Privilege and RLS end state

| Role | organizations | business_units | profiles | schema private | private functions |
|---|---|---|---|---|---|
| `anon` | none | none | none | none | no EXECUTE |
| `authenticated` | none | none | none | none (no USAGE) | no EXECUTE |
| `PUBLIC` | none | none | none | none | no EXECUTE |
| `service_role` | ALL | ALL | ALL | none needed | n/a |

RLS: enabled on all three tables, **zero policies**. Grants and RLS block independently. `service_role` (server/bootstrap path only, never the browser) bypasses RLS by design and holds the sole privilege on the three tables. Both `private` functions are still invoked normally because trigger execution does not consult EXECUTE privileges, and `handle_new_auth_user` returns `trigger`, so PostgREST cannot invoke it as an RPC even if the schema were ever exposed.

`CREATE SCHEMA` / `CREATE TABLE` still grant ownership to the migration owner (postgres role); nothing else receives implicit privileges. No reliance on Supabase default privileges.

## 4. Atomicity statement

The migration will be applied through the Lovable migration tool, which submits the complete migration SQL as a single execution batch to the database; any statement failure aborts the batch and leaves no partially secured state (no table created without its `ENABLE ROW LEVEL SECURITY`, no function left without its revokes). **Therefore Batch 1 contains no explicit `BEGIN;`/`COMMIT;` — adding them would break single-transaction wrapping if the runner also opens one.** Before execution this is verified once with a trivial no-op confirmation of runner behavior; if that verification shows statements are applied non-transactionally, an explicit `BEGIN; ... COMMIT;` will be added to the top/bottom of this file before it is ever executed.

## 5. Final Batch 1 acceptance checklist

- [ ] `private` schema created with plain `CREATE SCHEMA` (fails if it already exists); no `USAGE` to `anon`/`authenticated`.
- [ ] Both functions created with plain `CREATE FUNCTION` (fail on name collision); `set_updated_at` NOT SECURITY DEFINER; `handle_new_auth_user` SECURITY DEFINER; both `search_path = ''`.
- [ ] `organizations`, `business_units`, `profiles` exist with exactly the stated PK/FK/UNIQUE/CHECK set.
- [ ] Indexes: only the three PKs, `business_units_org_code_key`, `profiles_employee_code_key`. No `organizations_active_idx`, no standalone FK index.
- [ ] `business_units.organization_id → organizations ON DELETE RESTRICT`; `profiles.id → auth.users ON DELETE CASCADE`.
- [ ] Defaults kept: country `MX`, timezone `America/Mazatlan`, currency `MXN`; `legal_name` NOT NULL; `first_name`/`last_name` nullable.
- [ ] `handle_new_auth_user`: single INSERT, defensive metadata parsing, **no `ON CONFLICT`**, no swallowing of exceptions, no organization/role/membership logic.
- [ ] `profiles_set_updated_at` changes only `updated_at`.
- [ ] RLS enabled on all three tables with zero policies; `anon`/`authenticated` hold no privilege and can read no rows; `service_role` holds `ALL`.
- [ ] No seed data, no personal identifiers, no environment UUIDs, no DROP/CASCADE, no app code changes.
- [ ] Runner atomicity verified before execution per §4; no redundant `BEGIN`/`COMMIT` if the runner wraps transactions.
