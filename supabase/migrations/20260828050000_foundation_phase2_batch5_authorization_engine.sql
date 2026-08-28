-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 5
-- Authorization engine / platform administration
--
-- This migration:
--   - creates private.platform_admins
--   - creates private authorization helper functions
--   - keeps Superadmin separate from business roles
--   - does NOT create business-data RLS policies
--   - does NOT seed a Superadmin
--   - does NOT grant direct table access to authenticated users
-- ============================================================


-- ============================================================
-- 1. private.platform_admins
--
-- Platform administration is an independent authorization plane.
-- A platform admin is NOT a business role and is NOT F4.
-- ============================================================

CREATE TABLE private.platform_admins (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id      uuid        NOT NULL
               REFERENCES auth.users (id)
               ON DELETE CASCADE,

  admin_level  text        NOT NULL DEFAULT 'superadmin',

  is_active    boolean     NOT NULL DEFAULT true,

  created_at   timestamptz NOT NULL DEFAULT now(),

  created_by   uuid        NULL
               REFERENCES auth.users (id)
               ON DELETE SET NULL,

  CONSTRAINT platform_admins_admin_level_check
    CHECK (admin_level = 'superadmin')
);

CREATE UNIQUE INDEX platform_admins_active_user_key
  ON private.platform_admins (user_id)
  WHERE is_active = true;

ALTER TABLE private.platform_admins
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE private.platform_admins
  FROM PUBLIC;

REVOKE ALL
  ON TABLE private.platform_admins
  FROM anon;

REVOKE ALL
  ON TABLE private.platform_admins
  FROM authenticated;

GRANT ALL
  ON TABLE private.platform_admins
  TO service_role;


-- ============================================================
-- 2. private.is_superadmin()
--
-- Superadmin grants PLATFORM authority only.
-- It intentionally does not imply organization membership,
-- project membership or financial access.
-- ============================================================

CREATE FUNCTION private.is_superadmin()
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

      FROM private.platform_admins pa

      JOIN public.profiles pr
        ON pr.id = pa.user_id

      WHERE pa.user_id = (SELECT auth.uid())

        AND pa.admin_level = 'superadmin'
        AND pa.is_active = true
        AND pr.is_active = true
    );
$$;


-- ============================================================
-- 3. private.is_organization_member(uuid)
--
-- Organization membership is valid only when:
--   - authenticated user exists
--   - profile is active
--   - organization membership is active
--   - organization itself is active
-- ============================================================

CREATE FUNCTION private.is_organization_member(
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

      WHERE om.organization_id = p_organization_id
        AND om.user_id = (SELECT auth.uid())

        AND om.is_active = true
        AND pr.is_active = true
        AND org.is_active = true
    );
$$;


-- ============================================================
-- 4. private.has_org_permission(uuid, text)
--
-- organization_id is explicit so authority from one organization
-- can never leak into another organization.
--
-- Only organization-scoped role mappings are considered.
-- ============================================================

CREATE FUNCTION private.has_org_permission(
  p_organization_id uuid,
  p_permission_code text
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

    AND p_permission_code IS NOT NULL

    AND EXISTS (
      SELECT 1

      FROM public.organization_members om

      JOIN public.profiles pr
        ON pr.id = om.user_id

      JOIN public.organizations org
        ON org.id = om.organization_id

      JOIN public.roles r
        ON r.id = om.role_id

      JOIN public.role_permissions rp
        ON rp.role_id = r.id
       AND rp.scope = 'organization'

      JOIN public.permissions perm
        ON perm.id = rp.permission_id

      WHERE om.organization_id = p_organization_id
        AND om.user_id = (SELECT auth.uid())

        AND om.is_active = true
        AND pr.is_active = true
        AND org.is_active = true

        AND r.is_active = true
        AND perm.is_active = true

        AND perm.code = p_permission_code
    );
$$;


-- ============================================================
-- 5. private.is_project_member(uuid)
--
-- A project membership is valid only when every part of the
-- authority chain remains active:
--
--   profile
--   organization
--   organization membership
--   project
--   project membership
--   project role
-- ============================================================

CREATE FUNCTION private.is_project_member(
  p_project_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    (SELECT auth.uid()) IS NOT NULL

    AND p_project_id IS NOT NULL

    AND EXISTS (
      SELECT 1

      FROM public.project_members pm

      JOIN public.projects proj
        ON proj.id = pm.project_id
       AND proj.organization_id = pm.organization_id

      JOIN public.organizations org
        ON org.id = proj.organization_id

      JOIN public.organization_members om
        ON om.organization_id = pm.organization_id
       AND om.user_id = pm.user_id

      JOIN public.profiles pr
        ON pr.id = pm.user_id

      JOIN public.roles r
        ON r.id = pm.role_id

      WHERE pm.project_id = p_project_id
        AND pm.user_id = (SELECT auth.uid())

        AND pm.is_active = true
        AND om.is_active = true
        AND pr.is_active = true
        AND proj.is_active = true
        AND org.is_active = true
        AND r.is_active = true
    );
$$;


-- ============================================================
-- 6. private.has_project_permission(uuid, text)
--
-- Project overrides take precedence:
--
-- explicit DENY  -> false
-- explicit ALLOW -> true
-- no override    -> project-role mapping
--
-- Organization-scoped permissions are intentionally ignored.
--
-- A disabled project role invalidates both the role mapping and
-- any project-level override.
-- ============================================================

CREATE FUNCTION private.has_project_permission(
  p_project_id uuid,
  p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH membership AS (
    SELECT
      pm.id      AS project_member_id,
      pm.role_id AS role_id

    FROM public.project_members pm

    JOIN public.projects proj
      ON proj.id = pm.project_id
     AND proj.organization_id = pm.organization_id

    JOIN public.organizations org
      ON org.id = proj.organization_id

    JOIN public.organization_members om
      ON om.organization_id = pm.organization_id
     AND om.user_id = pm.user_id

    JOIN public.profiles pr
      ON pr.id = pm.user_id

    JOIN public.roles r
      ON r.id = pm.role_id

    WHERE pm.project_id = p_project_id
      AND pm.user_id = (SELECT auth.uid())

      AND pm.is_active = true
      AND om.is_active = true
      AND pr.is_active = true
      AND proj.is_active = true
      AND org.is_active = true
      AND r.is_active = true

    LIMIT 1
  ),

  permission AS (
    SELECT
      p.id,
      p.code

    FROM public.permissions p

    WHERE p.code = p_permission_code
      AND p.is_active = true

      -- Administration authority is never project-scoped.
      AND p.code NOT LIKE 'admin.%'

    LIMIT 1
  ),

  explicit_override AS (
    SELECT
      o.is_allowed

    FROM public.project_member_permission_overrides o

    JOIN membership m
      ON m.project_member_id = o.project_member_id

    JOIN permission p
      ON p.id = o.permission_id

    LIMIT 1
  )

  SELECT
    CASE

      WHEN (SELECT auth.uid()) IS NULL
        OR p_project_id IS NULL
        OR p_permission_code IS NULL
      THEN false

      WHEN NOT EXISTS (
        SELECT 1
        FROM membership
      )
      THEN false

      WHEN NOT EXISTS (
        SELECT 1
        FROM permission
      )
      THEN false

      -- Explicit deny wins.
      WHEN EXISTS (
        SELECT 1
        FROM explicit_override
        WHERE is_allowed = false
      )
      THEN false

      -- Explicit allow wins over role defaults.
      WHEN EXISTS (
        SELECT 1
        FROM explicit_override
        WHERE is_allowed = true
      )
      THEN true

      -- Otherwise use project-role permission mapping.
      ELSE EXISTS (
        SELECT 1

        FROM membership m

        JOIN public.roles r
          ON r.id = m.role_id
         AND r.is_active = true

        JOIN public.role_permissions rp
          ON rp.role_id = r.id
         AND rp.scope = 'project'

        JOIN permission p
          ON p.id = rp.permission_id
      )

    END;
$$;


-- ============================================================
-- 7. private.can_access_project(uuid)
--
-- Path A:
--   direct active project membership + project.view
--
-- Path B:
--   active organization membership + organization portfolio.view
--
-- A generic organization-scoped project.view is intentionally
-- NOT treated as portfolio access.
--
-- Superadmin intentionally does NOT participate.
-- ============================================================

CREATE FUNCTION private.can_access_project(
  p_project_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1

    FROM public.projects proj

    WHERE proj.id = p_project_id
      AND proj.is_active = true

      AND (
        private.has_project_permission(
          proj.id,
          'project.view'
        )

        OR

        private.has_org_permission(
          proj.organization_id,
          'portfolio.view'
        )
      )
  );
$$;


-- ============================================================
-- 8. private.effective_financial_level(uuid)
--
-- Returns the highest active financial clearance applicable to
-- the project.
--
-- IMPORTANT:
-- This function is informational/supporting only.
--
-- Authorization MUST use can_read_financial_class(), because
-- financial level and permission must belong to the SAME
-- authority path.
-- ============================================================

CREATE FUNCTION private.effective_financial_level(
  p_project_id uuid
)
RETURNS smallint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH project_context AS (
    SELECT
      proj.id,
      proj.organization_id

    FROM public.projects proj

    JOIN public.organizations org
      ON org.id = proj.organization_id

    WHERE proj.id = p_project_id
      AND proj.is_active = true
      AND org.is_active = true

    LIMIT 1
  ),

  project_level AS (
    SELECT
      pm.financial_level

    FROM public.project_members pm

    JOIN project_context pc
      ON pc.id = pm.project_id
     AND pc.organization_id = pm.organization_id

    JOIN public.organization_members om
      ON om.organization_id = pm.organization_id
     AND om.user_id = pm.user_id

    JOIN public.profiles pr
      ON pr.id = pm.user_id

    JOIN public.roles r
      ON r.id = pm.role_id

    WHERE pm.user_id = (SELECT auth.uid())

      AND pm.is_active = true
      AND om.is_active = true
      AND pr.is_active = true
      AND r.is_active = true

    LIMIT 1
  ),

  organization_level AS (
    SELECT
      om.financial_level

    FROM project_context pc

    JOIN public.organization_members om
      ON om.organization_id = pc.organization_id

    JOIN public.profiles pr
      ON pr.id = om.user_id

    JOIN public.roles r
      ON r.id = om.role_id

    WHERE om.user_id = (SELECT auth.uid())

      AND om.is_active = true
      AND pr.is_active = true
      AND r.is_active = true

      -- Organization financial clearance only supplements the
      -- project if that organization role actually carries at
      -- least one active organization-scoped financial authority.
      AND EXISTS (
        SELECT 1

        FROM public.role_permissions rp

        JOIN public.permissions perm
          ON perm.id = rp.permission_id

        WHERE rp.role_id = r.id
          AND rp.scope = 'organization'

          AND perm.is_active = true

          AND perm.code IN (
            'financial.cost_view',
            'financial.contract_view',
            'financial.margin_view',
            'financial.collection_view'
          )
      )

    LIMIT 1
  )

  SELECT
    CASE
      WHEN (SELECT auth.uid()) IS NULL
        OR p_project_id IS NULL
      THEN 0::smallint

      ELSE GREATEST(
        COALESCE(
          (SELECT financial_level FROM project_level),
          0
        ),
        COALESCE(
          (SELECT financial_level FROM organization_level),
          0
        )
      )::smallint
    END;
$$;


-- ============================================================
-- 9. private.can_read_financial_class(uuid, smallint, text)
--
-- This is the authoritative financial-read helper.
--
-- It NEVER combines a financial level from one authority path
-- with a permission from another path.
--
-- Required class mapping:
--
-- financial.cost_view       -> F2
-- financial.contract_view   -> F3
-- financial.margin_view     -> F4
-- financial.collection_view -> F4
--
-- Superadmin intentionally does NOT participate.
-- ============================================================

CREATE FUNCTION private.can_read_financial_class(
  p_project_id uuid,
  p_required_level smallint,
  p_permission_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH project_context AS (
    SELECT
      proj.id,
      proj.organization_id

    FROM public.projects proj

    JOIN public.organizations org
      ON org.id = proj.organization_id

    WHERE proj.id = p_project_id
      AND proj.is_active = true
      AND org.is_active = true

    LIMIT 1
  ),

  required_class AS (
    SELECT CASE p_permission_code

      WHEN 'financial.cost_view'
        THEN 2::smallint

      WHEN 'financial.contract_view'
        THEN 3::smallint

      WHEN 'financial.margin_view'
        THEN 4::smallint

      WHEN 'financial.collection_view'
        THEN 4::smallint

      ELSE NULL::smallint

    END AS required_level
  )

  SELECT
    CASE

      WHEN (SELECT auth.uid()) IS NULL
        OR p_project_id IS NULL
        OR p_permission_code IS NULL
      THEN false

      -- Reject an incorrect level/code combination.
      WHEN p_required_level IS NULL
        OR p_required_level NOT BETWEEN 0 AND 4
        OR p_required_level <> (
          SELECT required_level
          FROM required_class
        )
      THEN false

      WHEN NOT EXISTS (
        SELECT 1
        FROM project_context
      )
      THEN false

      ELSE

        -- ====================================================
        -- PROJECT AUTHORITY PATH
        -- ====================================================

        EXISTS (
          SELECT 1

          FROM public.project_members pm

          JOIN project_context pc
            ON pc.id = pm.project_id
           AND pc.organization_id = pm.organization_id

          JOIN public.organization_members om
            ON om.organization_id = pm.organization_id
           AND om.user_id = pm.user_id

          JOIN public.profiles pr
            ON pr.id = pm.user_id

          WHERE pm.user_id = (SELECT auth.uid())

            AND pm.is_active = true
            AND om.is_active = true
            AND pr.is_active = true

            AND pm.financial_level >= p_required_level

            AND private.has_project_permission(
              p_project_id,
              p_permission_code
            )
        )

        OR

        -- ====================================================
        -- ORGANIZATION AUTHORITY PATH
        -- ====================================================

        EXISTS (
          SELECT 1

          FROM project_context pc

          JOIN public.organization_members om
            ON om.organization_id = pc.organization_id

          JOIN public.profiles pr
            ON pr.id = om.user_id

          WHERE om.user_id = (SELECT auth.uid())

            AND om.is_active = true
            AND pr.is_active = true

            AND om.financial_level >= p_required_level

            AND private.has_org_permission(
              pc.organization_id,
              p_permission_code
            )
        )

    END;
$$;


-- ============================================================
-- 10. Function privileges
--
-- private is NOT an exposed Data API schema.
--
-- authenticated receives only schema USAGE + EXECUTE on these
-- exact authorization helpers so future RLS policies can call
-- them.
--
-- service_role receives schema USAGE so its explicit privileges
-- on private.platform_admins are usable.
--
-- No table privileges are granted to authenticated.
-- anon receives nothing.
-- ============================================================

GRANT USAGE ON SCHEMA private
  TO service_role;

GRANT USAGE ON SCHEMA private
  TO authenticated;


REVOKE ALL
  ON FUNCTION private.is_superadmin()
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.is_organization_member(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.has_org_permission(uuid, text)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.is_project_member(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.has_project_permission(uuid, text)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.can_access_project(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.effective_financial_level(uuid)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL
  ON FUNCTION private.can_read_financial_class(uuid, smallint, text)
  FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
  ON FUNCTION private.is_superadmin()
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.is_organization_member(uuid)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.has_org_permission(uuid, text)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.is_project_member(uuid)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.has_project_permission(uuid, text)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.can_access_project(uuid)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.effective_financial_level(uuid)
  TO authenticated;

GRANT EXECUTE
  ON FUNCTION private.can_read_financial_class(uuid, smallint, text)
  TO authenticated;


-- ============================================================
-- 11. Migration assertions
-- ============================================================

DO $$
BEGIN

  IF (
    SELECT count(*)
    FROM private.platform_admins
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 5 validation failed: platform_admins must start empty.';
  END IF;


  -- Superadmin must never be represented as a business role.
  IF EXISTS (
    SELECT 1

    FROM public.roles

    WHERE code IN (
      'SUPERADMIN',
      'SUPER_ADMIN',
      'PLATFORM_ADMIN'
    )
  ) THEN
    RAISE EXCEPTION
      'Batch 5 validation failed: platform admin found in business roles.';
  END IF;


  -- Business roles must still carry zero admin.* permissions.
  IF EXISTS (
    SELECT 1

    FROM public.role_permissions rp

    JOIN public.permissions p
      ON p.id = rp.permission_id

    WHERE p.code LIKE 'admin.%'
  ) THEN
    RAISE EXCEPTION
      'Batch 5 validation failed: admin permission assigned to business role.';
  END IF;

END;
$$;
