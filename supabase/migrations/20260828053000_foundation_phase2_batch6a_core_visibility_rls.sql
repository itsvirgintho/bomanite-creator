-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 6A
-- Core visibility RLS
--
-- This migration:
--   - introduces the first authenticated SELECT grants
--   - creates core visibility RLS policies
--   - keeps all browser mutations disabled
--   - keeps permissions / role_permissions / overrides private
--   - does NOT create financial RLS policies
--   - does NOT grant Superadmin business-data visibility
-- ============================================================


-- ============================================================
-- 1. private.is_active_profile()
--
-- Basic authenticated-user validity check.
-- ============================================================

CREATE FUNCTION private.is_active_profile()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (SELECT auth.uid()) IS NOT NULL

    AND EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.is_active = true
    );
$$;

REVOKE ALL
  ON FUNCTION private.is_active_profile()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.is_active_profile()
  TO authenticated;


-- ============================================================
-- 2. private.has_any_org_authority(uuid)
--
-- An organization membership by itself is NOT authority.
--
-- This becomes true only when the active organization role has
-- at least one active ORGANIZATION-scoped permission.
-- ============================================================

CREATE FUNCTION private.has_any_org_authority(
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (SELECT auth.uid()) IS NOT NULL

    AND p_organization_id IS NOT NULL

    AND EXISTS (
      SELECT 1

      FROM public.organization_members om

      JOIN public.profiles pr
        ON pr.id = om.user_id

      JOIN public.organizations org
        ON org.id = om.organization_id

      JOIN public.roles r
        ON r.id = om.role_id

      WHERE om.organization_id = p_organization_id
        AND om.user_id = (SELECT auth.uid())

        AND om.is_active = true
        AND pr.is_active = true
        AND org.is_active = true
        AND r.is_active = true

        AND EXISTS (
          SELECT 1

          FROM public.role_permissions rp

          JOIN public.permissions perm
            ON perm.id = rp.permission_id

          WHERE rp.role_id = r.id
            AND rp.scope = 'organization'
            AND perm.is_active = true
        )
    );
$$;

REVOKE ALL
  ON FUNCTION private.has_any_org_authority(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.has_any_org_authority(uuid)
  TO authenticated;


-- ============================================================
-- 3. private.has_any_business_authority()
--
-- Used for low-sensitivity catalogs such as business role names.
--
-- Valid authority can come from:
--
-- A. an active organization role with at least one org permission
-- B. an active project membership with project.view
--
-- Superadmin alone intentionally does NOT satisfy this helper.
-- ============================================================

CREATE FUNCTION private.has_any_business_authority()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (SELECT auth.uid()) IS NOT NULL

    AND private.is_active_profile()

    AND (
      EXISTS (
        SELECT 1

        FROM public.organization_members om

        WHERE om.user_id = (SELECT auth.uid())
          AND private.has_any_org_authority(
            om.organization_id
          )
      )

      OR

      EXISTS (
        SELECT 1

        FROM public.project_members pm

        WHERE pm.user_id = (SELECT auth.uid())

          AND private.has_project_permission(
            pm.project_id,
            'project.view'
          )
      )
    );
$$;

REVOKE ALL
  ON FUNCTION private.has_any_business_authority()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.has_any_business_authority()
  TO authenticated;


-- ============================================================
-- 4. private.can_access_organization(uuid)
--
-- Organization identity becomes visible through either:
--
-- A. real organization-scoped authority
-- B. at least one accessible project in that organization
--
-- Passive org membership with role NULL grants nothing.
-- Superadmin alone grants nothing.
-- ============================================================

CREATE FUNCTION private.can_access_organization(
  p_organization_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1

    FROM public.organizations org

    WHERE org.id = p_organization_id
      AND org.is_active = true

      AND (
        private.has_any_org_authority(
          org.id
        )

        OR

        EXISTS (
          SELECT 1

          FROM public.projects proj

          WHERE proj.organization_id = org.id

            AND private.can_access_project(
              proj.id
            )
        )
      )
  );
$$;

REVOKE ALL
  ON FUNCTION private.can_access_organization(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.can_access_organization(uuid)
  TO authenticated;


-- ============================================================
-- 5. private.can_access_business_unit(uuid)
--
-- Organization-scoped roles may see organization business units.
--
-- Project-only users may see only the business unit of an
-- accessible project, not every business unit in the company.
-- ============================================================

CREATE FUNCTION private.can_access_business_unit(
  p_business_unit_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1

    FROM public.business_units bu

    JOIN public.organizations org
      ON org.id = bu.organization_id

    WHERE bu.id = p_business_unit_id
      AND bu.is_active = true
      AND org.is_active = true

      AND (
        private.has_any_org_authority(
          bu.organization_id
        )

        OR

        EXISTS (
          SELECT 1

          FROM public.projects proj

          WHERE proj.business_unit_id = bu.id

            AND private.can_access_project(
              proj.id
            )
        )
      )
  );
$$;

REVOKE ALL
  ON FUNCTION private.can_access_business_unit(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.can_access_business_unit(uuid)
  TO authenticated;


-- ============================================================
-- 6. private.can_view_profile(uuid)
--
-- Everyone can read their own profile.
--
-- Other employee profiles are visible only through explicit
-- organization portfolio authority.
--
-- Project membership alone intentionally does NOT expose every
-- coworker's full profile row because profiles contains phone,
-- employee_code and other internal attributes.
-- ============================================================

CREATE FUNCTION private.can_view_profile(
  p_profile_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (SELECT auth.uid()) IS NOT NULL

    AND private.is_active_profile()

    AND p_profile_id IS NOT NULL

    AND (
      p_profile_id = (SELECT auth.uid())

      OR

      EXISTS (
        SELECT 1

        FROM public.profiles target_profile

        JOIN public.organization_members target_om
          ON target_om.user_id = target_profile.id

        JOIN public.organizations org
          ON org.id = target_om.organization_id

        WHERE target_profile.id = p_profile_id

          AND target_profile.is_active = true
          AND target_om.is_active = true
          AND org.is_active = true

          AND private.has_org_permission(
            target_om.organization_id,
            'portfolio.view'
          )
      )
    );
$$;

REVOKE ALL
  ON FUNCTION private.can_view_profile(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
  ON FUNCTION private.can_view_profile(uuid)
  TO authenticated;


-- ============================================================
-- 7. Explicit authenticated SELECT grants
--
-- GRANT controls whether the table is reachable.
-- RLS controls which rows are visible.
--
-- No INSERT / UPDATE / DELETE is granted.
-- ============================================================

GRANT SELECT
  ON TABLE public.organizations
  TO authenticated;

GRANT SELECT
  ON TABLE public.business_units
  TO authenticated;

GRANT SELECT
  ON TABLE public.profiles
  TO authenticated;

GRANT SELECT
  ON TABLE public.roles
  TO authenticated;

GRANT SELECT
  ON TABLE public.organization_members
  TO authenticated;

GRANT SELECT
  ON TABLE public.projects
  TO authenticated;

GRANT SELECT
  ON TABLE public.project_members
  TO authenticated;


-- ============================================================
-- 8. Authorization internals remain CLOSED to browser
-- ============================================================

REVOKE ALL
  ON TABLE public.permissions
  FROM authenticated;

REVOKE ALL
  ON TABLE public.role_permissions
  FROM authenticated;

REVOKE ALL
  ON TABLE public.project_member_permission_overrides
  FROM authenticated;


-- ============================================================
-- 9. organizations SELECT policy
-- ============================================================

CREATE POLICY organizations_select_authorized
ON public.organizations
FOR SELECT
TO authenticated
USING (
  private.can_access_organization(id)
);


-- ============================================================
-- 10. business_units SELECT policy
-- ============================================================

CREATE POLICY business_units_select_authorized
ON public.business_units
FOR SELECT
TO authenticated
USING (
  private.can_access_business_unit(id)
);


-- ============================================================
-- 11. profiles SELECT policy
-- ============================================================

CREATE POLICY profiles_select_authorized
ON public.profiles
FOR SELECT
TO authenticated
USING (
  private.can_view_profile(id)
);


-- ============================================================
-- 12. roles SELECT policy
--
-- Only active business users can read active business role names.
-- ============================================================

CREATE POLICY roles_select_authorized
ON public.roles
FOR SELECT
TO authenticated
USING (
  is_active = true
  AND (SELECT private.has_any_business_authority())
);


-- ============================================================
-- 13. organization_members SELECT policy
--
-- Normal user:
--   own membership only
--
-- portfolio.view:
--   active memberships within authorized organization
-- ============================================================

CREATE POLICY organization_members_select_authorized
ON public.organization_members
FOR SELECT
TO authenticated
USING (
  (SELECT private.is_active_profile())

  AND (
    (
      user_id = (SELECT auth.uid())

      AND private.is_organization_member(
        organization_id
      )
    )

    OR

    (
      is_active = true

      AND private.has_org_permission(
        organization_id,
        'portfolio.view'
      )
    )
  )
);


-- ============================================================
-- 14. projects SELECT policy
--
-- Uses the already-tested Batch 5 project access engine.
-- ============================================================

CREATE POLICY projects_select_authorized
ON public.projects
FOR SELECT
TO authenticated
USING (
  private.can_access_project(id)
);


-- ============================================================
-- 15. project_members SELECT policy
--
-- Normal user:
--   own project-membership records
--
-- portfolio.view:
--   active team membership records in authorized organization
--
-- Ordinary project members intentionally do NOT automatically
-- see every member's security metadata / financial_level.
-- ============================================================

CREATE POLICY project_members_select_authorized
ON public.project_members
FOR SELECT
TO authenticated
USING (
  (SELECT private.is_active_profile())

  AND (
    (
      user_id = (SELECT auth.uid())

      AND private.is_project_member(
        project_id
      )
    )

    OR

    (
      is_active = true

      AND private.has_org_permission(
        organization_id,
        'portfolio.view'
      )
    )
  )
);


-- ============================================================
-- 16. Migration assertions
-- ============================================================

DO $$
BEGIN

  -- ----------------------------------------------------------
  -- Exactly 7 new SELECT policies must exist.
  -- ----------------------------------------------------------

  IF (
    SELECT count(*)
    FROM pg_policies
    WHERE schemaname = 'public'
      AND policyname IN (
        'organizations_select_authorized',
        'business_units_select_authorized',
        'profiles_select_authorized',
        'roles_select_authorized',
        'organization_members_select_authorized',
        'projects_select_authorized',
        'project_members_select_authorized'
      )
      AND cmd = 'SELECT'
  ) <> 7 THEN
    RAISE EXCEPTION
      'Batch 6A validation failed: expected 7 SELECT policies.';
  END IF;


  -- ----------------------------------------------------------
  -- No mutation policies may exist on the 10 core tables.
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'

      AND tablename IN (
        'organizations',
        'business_units',
        'profiles',
        'roles',
        'permissions',
        'role_permissions',
        'organization_members',
        'projects',
        'project_members',
        'project_member_permission_overrides'
      )

      AND cmd <> 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6A validation failed: mutation policy detected.';
  END IF;


  -- ----------------------------------------------------------
  -- Internal authorization tables must still have ZERO policies.
  -- ----------------------------------------------------------

  IF EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'

      AND tablename IN (
        'permissions',
        'role_permissions',
        'project_member_permission_overrides'
      )
  ) THEN
    RAISE EXCEPTION
      'Batch 6A validation failed: authorization internals were exposed.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated must have SELECT on exactly the intended
  -- user-facing core tables.
  -- ----------------------------------------------------------

  IF NOT has_table_privilege(
    'authenticated',
    'public.organizations',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: organizations SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.business_units',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: business_units SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.profiles',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: profiles SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.roles',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: roles SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.organization_members',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: organization_members SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.projects',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: projects SELECT grant missing.';
  END IF;

  IF NOT has_table_privilege(
    'authenticated',
    'public.project_members',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'Batch 6A: project_members SELECT grant missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Authorization internals must still have no SELECT grant.
  -- ----------------------------------------------------------

  IF has_table_privilege(
    'authenticated',
    'public.permissions',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6A: permissions unexpectedly readable.';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.role_permissions',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6A: role_permissions unexpectedly readable.';
  END IF;

  IF has_table_privilege(
    'authenticated',
    'public.project_member_permission_overrides',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 6A: project overrides unexpectedly readable.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated must have ZERO browser mutations.
  -- ----------------------------------------------------------

  IF
    has_table_privilege('authenticated', 'public.organizations', 'INSERT')
    OR has_table_privilege('authenticated', 'public.organizations', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.organizations', 'DELETE')

    OR has_table_privilege('authenticated', 'public.business_units', 'INSERT')
    OR has_table_privilege('authenticated', 'public.business_units', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.business_units', 'DELETE')

    OR has_table_privilege('authenticated', 'public.profiles', 'INSERT')
    OR has_table_privilege('authenticated', 'public.profiles', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.profiles', 'DELETE')

    OR has_table_privilege('authenticated', 'public.roles', 'INSERT')
    OR has_table_privilege('authenticated', 'public.roles', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.roles', 'DELETE')

    OR has_table_privilege('authenticated', 'public.permissions', 'INSERT')
    OR has_table_privilege('authenticated', 'public.permissions', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.permissions', 'DELETE')

    OR has_table_privilege('authenticated', 'public.role_permissions', 'INSERT')
    OR has_table_privilege('authenticated', 'public.role_permissions', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.role_permissions', 'DELETE')

    OR has_table_privilege('authenticated', 'public.organization_members', 'INSERT')
    OR has_table_privilege('authenticated', 'public.organization_members', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.organization_members', 'DELETE')

    OR has_table_privilege('authenticated', 'public.projects', 'INSERT')
    OR has_table_privilege('authenticated', 'public.projects', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.projects', 'DELETE')

    OR has_table_privilege('authenticated', 'public.project_members', 'INSERT')
    OR has_table_privilege('authenticated', 'public.project_members', 'UPDATE')
    OR has_table_privilege('authenticated', 'public.project_members', 'DELETE')

    OR has_table_privilege(
      'authenticated',
      'public.project_member_permission_overrides',
      'INSERT'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_member_permission_overrides',
      'UPDATE'
    )
    OR has_table_privilege(
      'authenticated',
      'public.project_member_permission_overrides',
      'DELETE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 6A validation failed: browser mutation privilege detected.';
  END IF;


  -- ----------------------------------------------------------
  -- anon must still have no SELECT on any core table.
  -- ----------------------------------------------------------

  IF
    has_table_privilege('anon', 'public.organizations', 'SELECT')
    OR has_table_privilege('anon', 'public.business_units', 'SELECT')
    OR has_table_privilege('anon', 'public.profiles', 'SELECT')
    OR has_table_privilege('anon', 'public.roles', 'SELECT')
    OR has_table_privilege('anon', 'public.permissions', 'SELECT')
    OR has_table_privilege('anon', 'public.role_permissions', 'SELECT')
    OR has_table_privilege('anon', 'public.organization_members', 'SELECT')
    OR has_table_privilege('anon', 'public.projects', 'SELECT')
    OR has_table_privilege('anon', 'public.project_members', 'SELECT')
    OR has_table_privilege(
      'anon',
      'public.project_member_permission_overrides',
      'SELECT'
    )
  THEN
    RAISE EXCEPTION
      'Batch 6A validation failed: anon SELECT privilege detected.';
  END IF;

END;
$$;
