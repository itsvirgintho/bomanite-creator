-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 6B
-- Financial visibility RLS
--
-- This migration:
--   - grants authenticated SELECT only on F2/F3/F4 tables
--   - applies the authoritative financial authorization engine
--   - requires sufficient financial level AND permission
--     on the SAME authority path
--   - does NOT grant browser mutations
--   - does NOT grant financial visibility to Superadmin
--   - does NOT seed financial data
-- ============================================================


-- ============================================================
-- 1. Explicit browser grants
-- ============================================================

REVOKE ALL
  ON TABLE public.project_cost_financials
  FROM authenticated;

REVOKE ALL
  ON TABLE public.project_contract_financials
  FROM authenticated;

REVOKE ALL
  ON TABLE public.project_executive_financials
  FROM authenticated;


GRANT SELECT
  ON TABLE public.project_cost_financials
  TO authenticated;

GRANT SELECT
  ON TABLE public.project_contract_financials
  TO authenticated;

GRANT SELECT
  ON TABLE public.project_executive_financials
  TO authenticated;


-- anon remains completely blocked

REVOKE ALL
  ON TABLE public.project_cost_financials
  FROM anon;

REVOKE ALL
  ON TABLE public.project_contract_financials
  FROM anon;

REVOKE ALL
  ON TABLE public.project_executive_financials
  FROM anon;


-- ============================================================
-- 2. F2 — Project cost financials
--
-- Required:
--   financial_level >= F2
--   AND financial.cost_view
--
-- Both must belong to the SAME valid authority path.
-- ============================================================

CREATE POLICY project_cost_financials_select_authorized
ON public.project_cost_financials
FOR SELECT
TO authenticated
USING (
  private.can_read_financial_class(
    project_id,
    2::smallint,
    'financial.cost_view'
  )
);


-- ============================================================
-- 3. F3 — Project contract financials
--
-- Required:
--   financial_level >= F3
--   AND financial.contract_view
--
-- Both must belong to the SAME valid authority path.
-- ============================================================

CREATE POLICY project_contract_financials_select_authorized
ON public.project_contract_financials
FOR SELECT
TO authenticated
USING (
  private.can_read_financial_class(
    project_id,
    3::smallint,
    'financial.contract_view'
  )
);


-- ============================================================
-- 4. F4 — Project executive financials
--
-- Required:
--   financial_level >= F4
--   AND financial.margin_view
--
-- Both must belong to the SAME valid authority path.
-- ============================================================

CREATE POLICY project_executive_financials_select_authorized
ON public.project_executive_financials
FOR SELECT
TO authenticated
USING (
  private.can_read_financial_class(
    project_id,
    4::smallint,
    'financial.margin_view'
  )
);


-- ============================================================
-- 5. Migration assertions
-- ============================================================

DO $$
BEGIN

  -- ----------------------------------------------------------
  -- RLS must remain enabled on all three financial tables
  -- ----------------------------------------------------------

  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'project_cost_financials'
      AND c.relkind = 'r'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: RLS disabled on project_cost_financials.';
  END IF;


  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'project_contract_financials'
      AND c.relkind = 'r'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: RLS disabled on project_contract_financials.';
  END IF;


  IF NOT (
    SELECT c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'project_executive_financials'
      AND c.relkind = 'r'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: RLS disabled on project_executive_financials.';
  END IF;


  -- ----------------------------------------------------------
  -- Exactly three intended SELECT policies must exist
  -- ----------------------------------------------------------

  IF (
    SELECT count(*)
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
        'project_cost_financials_select_authorized',
        'project_contract_financials_select_authorized',
        'project_executive_financials_select_authorized'
      )
      AND cmd = 'SELECT'
  ) <> 3 THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: expected exactly 3 financial SELECT policies.';
  END IF;


  -- ----------------------------------------------------------
  -- Each financial table must have exactly one policy total
  -- ----------------------------------------------------------

  IF (
    SELECT count(*)
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'project_cost_financials'
  ) <> 1 THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: unexpected policy count on project_cost_financials.';
  END IF;


  IF (
    SELECT count(*)
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'project_contract_financials'
  ) <> 1 THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: unexpected policy count on project_contract_financials.';
  END IF;


  IF (
    SELECT count(*)
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'project_executive_financials'
  ) <> 1 THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: unexpected policy count on project_executive_financials.';
  END IF;


  -- ----------------------------------------------------------
  -- ZERO financial mutation policies
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'project_cost_financials',
        'project_contract_financials',
        'project_executive_financials'
      )
      AND cmd <> 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: financial mutation policy detected.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated must have SELECT on all three tables
  -- ----------------------------------------------------------

  IF NOT has_table_privilege(
    'authenticated',
    'public.project_cost_financials',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: authenticated F2 SELECT missing.';
  END IF;


  IF NOT has_table_privilege(
    'authenticated',
    'public.project_contract_financials',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: authenticated F3 SELECT missing.';
  END IF;


  IF NOT has_table_privilege(
    'authenticated',
    'public.project_executive_financials',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: authenticated F4 SELECT missing.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated must have ZERO INSERT / UPDATE / DELETE
  -- ----------------------------------------------------------

  IF
    has_table_privilege(
      'authenticated',
      'public.project_cost_financials',
      'INSERT'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_cost_financials',
      'UPDATE'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_cost_financials',
      'DELETE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.project_contract_financials',
      'INSERT'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_contract_financials',
      'UPDATE'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_contract_financials',
      'DELETE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.project_executive_financials',
      'INSERT'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_executive_financials',
      'UPDATE'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_executive_financials',
      'DELETE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: authenticated financial mutation privilege detected.';
  END IF;


  -- ----------------------------------------------------------
  -- anon must remain blocked
  -- ----------------------------------------------------------

  IF
    has_table_privilege(
      'anon',
      'public.project_cost_financials',
      'SELECT'
    )
    OR has_table_privilege(
      'anon',
      'public.project_contract_financials',
      'SELECT'
    )
    OR has_table_privilege(
      'anon',
      'public.project_executive_financials',
      'SELECT'
    )
  THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: anon financial SELECT detected.';
  END IF;


  -- ----------------------------------------------------------
  -- Authoritative financial helper must exist
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'can_read_financial_class'
      AND pg_get_function_identity_arguments(p.oid)
        = 'p_project_id uuid, p_required_level smallint, p_permission_code text'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: financial authorization helper missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Financial helper must remain SECURITY DEFINER
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'can_read_financial_class'
      AND pg_get_function_identity_arguments(p.oid)
        = 'p_project_id uuid, p_required_level smallint, p_permission_code text'
      AND p.prosecdef = true
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: financial helper is not SECURITY DEFINER.';
  END IF;


  -- ----------------------------------------------------------
  -- Financial helper search_path must remain locked
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n
      ON n.oid = p.pronamespace
    WHERE n.nspname = 'private'
      AND p.proname = 'can_read_financial_class'
      AND pg_get_function_identity_arguments(p.oid)
        = 'p_project_id uuid, p_required_level smallint, p_permission_code text'
      AND p.proconfig IS NOT NULL
      AND 'search_path=""' = ANY(p.proconfig)
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: financial helper search_path is not locked.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated can execute helper for RLS evaluation
  -- ----------------------------------------------------------

  IF NOT has_function_privilege(
    'authenticated',
    'private.can_read_financial_class(uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: authenticated cannot execute financial helper.';
  END IF;


  -- ----------------------------------------------------------
  -- anon must NOT execute helper
  -- ----------------------------------------------------------

  IF has_function_privilege(
    'anon',
    'private.can_read_financial_class(uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: anon can execute financial helper.';
  END IF;


  -- ----------------------------------------------------------
  -- PUBLIC must NOT execute helper
  --
  -- PUBLIC is a PostgreSQL pseudo-role, represented as
  -- grantee OID 0 in ACLs. It cannot be passed as a normal
  -- role name to has_function_privilege().
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
      AND p.proname = 'can_read_financial_class'

      AND pg_get_function_identity_arguments(p.oid)
        = 'p_project_id uuid, p_required_level smallint, p_permission_code text'

      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 6B validation failed: PUBLIC can execute financial helper.';
  END IF;

END;
$$;
