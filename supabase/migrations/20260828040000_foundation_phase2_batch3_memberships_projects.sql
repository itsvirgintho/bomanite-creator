-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 3
-- Memberships, projects, financial levels and project overrides
--
-- This migration:
--   - creates organization memberships
--   - creates core projects
--   - creates project memberships
--   - creates project permission overrides
--   - introduces F0-F4 financial levels
--   - does NOT create financial data tables
--   - does NOT create Superadmin
--   - does NOT create RLS access policies
--   - does NOT grant browser access
--   - does NOT seed real organizations, projects or users
-- ============================================================


-- ============================================================
-- 1. public.organization_members
-- ============================================================

CREATE TABLE public.organization_members (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id    uuid        NOT NULL
                     REFERENCES public.organizations (id)
                     ON DELETE RESTRICT,

  user_id             uuid        NOT NULL
                     REFERENCES public.profiles (id)
                     ON DELETE RESTRICT,

  role_id             uuid        NULL
                     REFERENCES public.roles (id)
                     ON DELETE RESTRICT,

  financial_level     smallint    NOT NULL DEFAULT 0,

  is_active           boolean     NOT NULL DEFAULT true,

  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT organization_members_org_user_key
    UNIQUE (organization_id, user_id),

  CONSTRAINT organization_members_financial_level_check
    CHECK (financial_level BETWEEN 0 AND 4)
);

COMMENT ON COLUMN public.organization_members.financial_level IS
  'Financial clearance only: 0=F0, 1=F1, 2=F2, 3=F3, 4=F4. '
  'A financial level never grants access without an applicable permission.';

CREATE INDEX organization_members_user_id_idx
  ON public.organization_members (user_id);

CREATE INDEX organization_members_role_id_idx
  ON public.organization_members (role_id)
  WHERE role_id IS NOT NULL;

CREATE TRIGGER organization_members_set_updated_at
  BEFORE UPDATE ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.organization_members FROM PUBLIC;
REVOKE ALL ON TABLE public.organization_members FROM anon;
REVOKE ALL ON TABLE public.organization_members FROM authenticated;

GRANT ALL ON TABLE public.organization_members TO service_role;


-- ============================================================
-- 2. business_units integrity support
--
-- The primary key already guarantees id uniqueness.
-- This additional composite key exists so projects can enforce
-- that a business_unit_id belongs to the same organization_id.
-- ============================================================

ALTER TABLE public.business_units
  ADD CONSTRAINT business_units_id_organization_key
  UNIQUE (id, organization_id);


-- ============================================================
-- 3. public.projects
-- ============================================================

CREATE TABLE public.projects (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id    uuid        NOT NULL
                     REFERENCES public.organizations (id)
                     ON DELETE RESTRICT,

  business_unit_id   uuid        NULL,

  code               text        NOT NULL,
  name               text        NOT NULL,

  client_name        text        NULL,
  location_label     text        NULL,

  status             text        NOT NULL DEFAULT 'active',

  start_date         date        NULL,
  end_date           date        NULL,

  is_active          boolean     NOT NULL DEFAULT true,

  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT projects_org_code_key
    UNIQUE (organization_id, code),

  -- Supports the composite FK used by project_members.
  CONSTRAINT projects_id_organization_key
    UNIQUE (id, organization_id),

  CONSTRAINT projects_business_unit_org_fkey
    FOREIGN KEY (business_unit_id, organization_id)
    REFERENCES public.business_units (id, organization_id)
    ON DELETE RESTRICT,

  CONSTRAINT projects_code_not_blank
    CHECK (length(btrim(code)) > 0),

  CONSTRAINT projects_name_not_blank
    CHECK (length(btrim(name)) > 0),

  CONSTRAINT projects_client_name_not_blank
    CHECK (
      client_name IS NULL
      OR length(btrim(client_name)) > 0
    ),

  CONSTRAINT projects_location_label_not_blank
    CHECK (
      location_label IS NULL
      OR length(btrim(location_label)) > 0
    ),

  CONSTRAINT projects_status_check
    CHECK (
      status IN (
        'planning',
        'active',
        'on_hold',
        'completed',
        'cancelled'
      )
    ),

  CONSTRAINT projects_dates_check
    CHECK (
      start_date IS NULL
      OR end_date IS NULL
      OR end_date >= start_date
    )
);

CREATE INDEX projects_business_unit_id_idx
  ON public.projects (business_unit_id)
  WHERE business_unit_id IS NOT NULL;

CREATE TRIGGER projects_set_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.projects FROM PUBLIC;
REVOKE ALL ON TABLE public.projects FROM anon;
REVOKE ALL ON TABLE public.projects FROM authenticated;

GRANT ALL ON TABLE public.projects TO service_role;


-- ============================================================
-- 4. public.project_members
--
-- organization_id is intentionally repeated here so PostgreSQL
-- can enforce BOTH:
--
--   1. the user belongs to the organization
--   2. the project belongs to the same organization
--
-- This prevents cross-organization membership corruption.
-- ============================================================

CREATE TABLE public.project_members (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  organization_id    uuid        NOT NULL,

  project_id         uuid        NOT NULL,

  user_id             uuid        NOT NULL,

  role_id             uuid        NOT NULL
                     REFERENCES public.roles (id)
                     ON DELETE RESTRICT,

  financial_level     smallint    NOT NULL DEFAULT 0,

  is_active           boolean     NOT NULL DEFAULT true,

  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT project_members_project_user_key
    UNIQUE (project_id, user_id),

  CONSTRAINT project_members_financial_level_check
    CHECK (financial_level BETWEEN 0 AND 4),

  CONSTRAINT project_members_org_membership_fkey
    FOREIGN KEY (organization_id, user_id)
    REFERENCES public.organization_members (
      organization_id,
      user_id
    )
    ON DELETE RESTRICT,

  CONSTRAINT project_members_project_org_fkey
    FOREIGN KEY (project_id, organization_id)
    REFERENCES public.projects (
      id,
      organization_id
    )
    ON DELETE RESTRICT
);

COMMENT ON COLUMN public.project_members.financial_level IS
  'Project-specific financial clearance only: '
  '0=F0, 1=F1, 2=F2, 3=F3, 4=F4. '
  'A financial level never grants access without an applicable permission.';

CREATE INDEX project_members_user_id_idx
  ON public.project_members (user_id);

CREATE INDEX project_members_org_user_idx
  ON public.project_members (organization_id, user_id);

CREATE INDEX project_members_role_id_idx
  ON public.project_members (role_id);

CREATE TRIGGER project_members_set_updated_at
  BEFORE UPDATE ON public.project_members
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.project_members FROM PUBLIC;
REVOKE ALL ON TABLE public.project_members FROM anon;
REVOKE ALL ON TABLE public.project_members FROM authenticated;

GRANT ALL ON TABLE public.project_members TO service_role;


-- ============================================================
-- 5. public.project_member_permission_overrides
--
-- Overrides are inherently PROJECT scoped.
-- Therefore this table intentionally has NO scope column.
--
-- is_allowed = true  -> explicit grant
-- is_allowed = false -> explicit deny
--
-- Financial permissions still require the appropriate
-- financial_level when evaluated by later authorization helpers.
-- ============================================================

CREATE TABLE public.project_member_permission_overrides (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),

  project_member_id  uuid        NOT NULL
                     REFERENCES public.project_members (id)
                     ON DELETE RESTRICT,

  permission_id      uuid        NOT NULL
                     REFERENCES public.permissions (id)
                     ON DELETE RESTRICT,

  is_allowed         boolean     NOT NULL,

  reason             text        NULL,

  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT project_member_permission_overrides_member_permission_key
    UNIQUE (project_member_id, permission_id),

  CONSTRAINT project_member_permission_overrides_reason_not_blank
    CHECK (
      reason IS NULL
      OR length(btrim(reason)) > 0
    )
);

CREATE INDEX project_member_permission_overrides_permission_id_idx
  ON public.project_member_permission_overrides (permission_id);

CREATE TRIGGER project_member_permission_overrides_set_updated_at
  BEFORE UPDATE ON public.project_member_permission_overrides
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.project_member_permission_overrides
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE public.project_member_permission_overrides
  FROM PUBLIC;

REVOKE ALL
  ON TABLE public.project_member_permission_overrides
  FROM anon;

REVOKE ALL
  ON TABLE public.project_member_permission_overrides
  FROM authenticated;

GRANT ALL
  ON TABLE public.project_member_permission_overrides
  TO service_role;


-- ============================================================
-- 6. Prevent project overrides from granting admin permissions
--
-- Superadmin / administration authority must never be obtained
-- through a project membership override.
-- ============================================================

CREATE FUNCTION private.prevent_admin_project_permission_override()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN

  IF EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.id = NEW.permission_id
      AND p.code LIKE 'admin.%'
  ) THEN
    RAISE EXCEPTION
      'admin permissions cannot be assigned through project overrides';
  END IF;

  RETURN NEW;

END;
$$;

REVOKE ALL
  ON FUNCTION private.prevent_admin_project_permission_override()
  FROM PUBLIC;

REVOKE ALL
  ON FUNCTION private.prevent_admin_project_permission_override()
  FROM anon;

REVOKE ALL
  ON FUNCTION private.prevent_admin_project_permission_override()
  FROM authenticated;

CREATE TRIGGER project_permission_override_block_admin
  BEFORE INSERT OR UPDATE OF permission_id
  ON public.project_member_permission_overrides
  FOR EACH ROW
  EXECUTE FUNCTION private.prevent_admin_project_permission_override();


-- ============================================================
-- 7. Migration assertions
-- ============================================================

DO $$
BEGIN

  IF (
    SELECT count(*)
    FROM public.organization_members
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 3 validation failed: organization_members must start empty.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.projects
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 3 validation failed: projects must start empty.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.project_members
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 3 validation failed: project_members must start empty.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.project_member_permission_overrides
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 3 validation failed: project overrides must start empty.';
  END IF;

END;
$$;
