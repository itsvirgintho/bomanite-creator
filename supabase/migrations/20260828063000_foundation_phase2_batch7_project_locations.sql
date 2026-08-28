-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 7
-- Project Locations
--
-- Hierarchical project locations using an adjacency-list model.
--
-- Security:
--   - authenticated: SELECT only
--   - anon: no access
--   - browser mutations: none
--   - visibility derives exclusively from can_access_project()
--   - Superadmin alone grants no project-location visibility
--
-- Integrity:
--   - parent must belong to the same project
--   - self-parent is prohibited
--   - deep hierarchy cycles are prohibited
--   - sibling names are unique
--   - project location codes are unique when supplied
-- ============================================================


-- ============================================================
-- 1. public.project_locations
-- ============================================================

CREATE TABLE public.project_locations (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  project_id      uuid        NOT NULL
                  REFERENCES public.projects (id)
                  ON DELETE RESTRICT,

  parent_id       uuid        NULL,

  code            text        NULL,
  name            text        NOT NULL,
  location_type   text        NULL,

  sort_order      integer     NOT NULL DEFAULT 0,

  is_active       boolean     NOT NULL DEFAULT true,

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),


  -- ----------------------------------------------------------
  -- Required so the self-referential FK can enforce:
  --
  --   parent_id belongs to the SAME project_id.
  -- ----------------------------------------------------------

  CONSTRAINT project_locations_id_project_key
    UNIQUE (id, project_id),


  -- ----------------------------------------------------------
  -- Parent belongs to same project.
  -- ----------------------------------------------------------

  CONSTRAINT project_locations_parent_same_project_fkey
    FOREIGN KEY (parent_id, project_id)
    REFERENCES public.project_locations (
      id,
      project_id
    )
    ON DELETE RESTRICT,


  -- ----------------------------------------------------------
  -- Basic integrity
  -- ----------------------------------------------------------

  CONSTRAINT project_locations_parent_not_self
    CHECK (
      parent_id IS NULL
      OR parent_id <> id
    ),

  CONSTRAINT project_locations_name_not_blank
    CHECK (
      length(btrim(name)) > 0
    ),

  CONSTRAINT project_locations_code_not_blank
    CHECK (
      code IS NULL
      OR length(btrim(code)) > 0
    ),

  CONSTRAINT project_locations_type_not_blank
    CHECK (
      location_type IS NULL
      OR length(btrim(location_type)) > 0
    ),

  CONSTRAINT project_locations_sort_order_check
    CHECK (
      sort_order >= 0
    )
);


-- ============================================================
-- 2. Uniqueness
--
-- PostgreSQL treats NULL values independently in normal UNIQUE
-- constraints, so root and child names are handled separately.
-- ============================================================


-- Root locations:
--
-- Project A
--   ├── Torre 1
--   └── Torre 2
--
-- cannot contain two root nodes with the same normalized name.

CREATE UNIQUE INDEX project_locations_root_name_key
ON public.project_locations (
  project_id,
  lower(btrim(name))
)
WHERE parent_id IS NULL;


-- Children under the SAME parent must have unique names.
--
-- Torre 1
--   ├── Nivel 5
--   └── Nivel 10
--
-- Another Torre may independently contain its own "Nivel 5".

CREATE UNIQUE INDEX project_locations_sibling_name_key
ON public.project_locations (
  project_id,
  parent_id,
  lower(btrim(name))
)
WHERE parent_id IS NOT NULL;


-- Optional codes are unique inside a project.

CREATE UNIQUE INDEX project_locations_project_code_key
ON public.project_locations (
  project_id,
  lower(btrim(code))
)
WHERE code IS NOT NULL;


-- ============================================================
-- 3. Query indexes
-- ============================================================

CREATE INDEX project_locations_project_parent_sort_idx
ON public.project_locations (
  project_id,
  parent_id,
  sort_order
);


CREATE INDEX project_locations_parent_id_idx
ON public.project_locations (parent_id)
WHERE parent_id IS NOT NULL;


-- ============================================================
-- 4. Deep-cycle prevention
--
-- The foreign key prevents cross-project parents.
--
-- The CHECK constraint prevents:
--
--     A -> A
--
-- This trigger additionally prevents:
--
--     A -> B
--     B -> C
--     C -> A
--
-- UNION rather than UNION ALL intentionally protects traversal
-- even if corrupted cyclic data somehow already existed.
-- ============================================================

CREATE FUNCTION private.prevent_project_location_cycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_cycle boolean;
BEGIN

  -- Root nodes cannot form a parent cycle.
  IF NEW.parent_id IS NULL THEN
    RETURN NEW;
  END IF;


  -- Defensive duplicate of the CHECK constraint.
  IF NEW.parent_id = NEW.id THEN
    RAISE EXCEPTION
      'A project location cannot be its own parent.'
      USING ERRCODE = '23514';
  END IF;


  WITH RECURSIVE ancestors (
    id,
    parent_id
  ) AS (

    -- Start at the proposed parent.
    SELECT
      pl.id,
      pl.parent_id

    FROM public.project_locations pl

    WHERE pl.id = NEW.parent_id
      AND pl.project_id = NEW.project_id


    UNION


    -- Walk upward through every ancestor.
    SELECT
      pl.id,
      pl.parent_id

    FROM public.project_locations pl

    JOIN ancestors a
      ON pl.id = a.parent_id

    WHERE pl.project_id = NEW.project_id
  )

  SELECT EXISTS (
    SELECT 1
    FROM ancestors
    WHERE id = NEW.id
  )
  INTO v_cycle;


  IF v_cycle THEN
    RAISE EXCEPTION
      'Project location hierarchy cycle detected.'
      USING ERRCODE = '23514';
  END IF;


  RETURN NEW;
END;
$$;


REVOKE ALL
ON FUNCTION private.prevent_project_location_cycle()
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION private.prevent_project_location_cycle()
TO service_role;


-- ============================================================
-- 5. Cycle trigger
-- ============================================================

CREATE TRIGGER project_locations_prevent_cycle
BEFORE INSERT OR UPDATE OF id, project_id, parent_id
ON public.project_locations
FOR EACH ROW
EXECUTE FUNCTION private.prevent_project_location_cycle();


-- ============================================================
-- 6. updated_at
-- ============================================================

CREATE TRIGGER project_locations_set_updated_at
BEFORE UPDATE
ON public.project_locations
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();


-- ============================================================
-- 7. RLS + explicit privileges
-- ============================================================

ALTER TABLE public.project_locations
ENABLE ROW LEVEL SECURITY;


REVOKE ALL
ON TABLE public.project_locations
FROM PUBLIC;


REVOKE ALL
ON TABLE public.project_locations
FROM anon;


REVOKE ALL
ON TABLE public.project_locations
FROM authenticated;


GRANT ALL
ON TABLE public.project_locations
TO service_role;


-- Browser receives read access only.

GRANT SELECT
ON TABLE public.project_locations
TO authenticated;


-- ============================================================
-- 8. SELECT policy
--
-- Location visibility follows project visibility exactly.
--
-- No separate Superadmin path exists.
-- ============================================================

CREATE POLICY project_locations_select_authorized
ON public.project_locations
FOR SELECT
TO authenticated
USING (
  private.can_access_project(project_id)
);


-- ============================================================
-- 9. Migration assertions
-- ============================================================

DO $$
BEGIN

  -- ----------------------------------------------------------
  -- Table exists
  -- ----------------------------------------------------------

  IF to_regclass('public.project_locations') IS NULL THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: project_locations missing.';
  END IF;


  -- ----------------------------------------------------------
  -- RLS enabled
  -- ----------------------------------------------------------

  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c

    JOIN pg_namespace n
      ON n.oid = c.relnamespace

    WHERE n.nspname = 'public'
      AND c.relname = 'project_locations'
      AND c.relkind = 'r'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: RLS disabled.';
  END IF;


  -- ----------------------------------------------------------
  -- Same-project parent FK exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_constraint c

    JOIN pg_class t
      ON t.oid = c.conrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'project_locations'
      AND c.conname =
        'project_locations_parent_same_project_fkey'
      AND c.contype = 'f'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: same-project parent FK missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Self-parent protection exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_constraint c

    JOIN pg_class t
      ON t.oid = c.conrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'project_locations'
      AND c.conname =
        'project_locations_parent_not_self'
      AND c.contype = 'c'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: self-parent constraint missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Cycle function exists and is SECURITY DEFINER
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'private'
      AND p.proname =
        'prevent_project_location_cycle'
      AND p.prosecdef = true
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: cycle function missing or not SECURITY DEFINER.';
  END IF;


  -- ----------------------------------------------------------
  -- Cycle function search_path locked
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'private'
      AND p.proname =
        'prevent_project_location_cycle'
      AND p.proconfig IS NOT NULL
      AND 'search_path=""' = ANY(p.proconfig)
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: cycle function search_path not locked.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated cannot directly execute cycle helper
  -- ----------------------------------------------------------

  IF has_function_privilege(
    'authenticated',
    'private.prevent_project_location_cycle()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: authenticated can directly execute cycle helper.';
  END IF;


  -- ----------------------------------------------------------
  -- anon cannot directly execute cycle helper
  -- ----------------------------------------------------------

  IF has_function_privilege(
    'anon',
    'private.prevent_project_location_cycle()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: anon can directly execute cycle helper.';
  END IF;


  -- ----------------------------------------------------------
  -- PUBLIC pseudo-role cannot execute cycle helper
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        p.proacl,
        acldefault('f', p.proowner)
      )
    ) AS acl

    WHERE n.nspname = 'private'
      AND p.proname =
        'prevent_project_location_cycle'
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: PUBLIC can execute cycle helper.';
  END IF;


  -- ----------------------------------------------------------
  -- Cycle trigger exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_trigger tg

    JOIN pg_class t
      ON t.oid = tg.tgrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'project_locations'
      AND tg.tgname =
        'project_locations_prevent_cycle'
      AND tg.tgisinternal = false
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: cycle trigger missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Exactly one RLS policy
  -- ----------------------------------------------------------

  IF (
    SELECT count(*)

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'project_locations'
  ) <> 1 THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: unexpected policy count.';
  END IF;


  -- ----------------------------------------------------------
  -- It must be the intended SELECT policy
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'project_locations'
      AND policyname =
        'project_locations_select_authorized'
      AND cmd = 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: SELECT policy missing.';
  END IF;


  -- ----------------------------------------------------------
  -- No mutation policy
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'project_locations'
      AND cmd <> 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: mutation policy detected.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated SELECT enabled
  -- ----------------------------------------------------------

  IF NOT has_table_privilege(
    'authenticated',
    'public.project_locations',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: authenticated SELECT missing.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated mutations blocked
  -- ----------------------------------------------------------

  IF
    has_table_privilege(
      'authenticated',
      'public.project_locations',
      'INSERT'
    )

    OR has_table_privilege(
      'authenticated',
      'public.project_locations',
      'UPDATE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.project_locations',
      'DELETE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: authenticated mutation privilege detected.';
  END IF;


  -- ----------------------------------------------------------
  -- anon completely blocked
  -- ----------------------------------------------------------

  IF has_table_privilege(
    'anon',
    'public.project_locations',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 7 validation failed: anon SELECT detected.';
  END IF;

END;
$$;
