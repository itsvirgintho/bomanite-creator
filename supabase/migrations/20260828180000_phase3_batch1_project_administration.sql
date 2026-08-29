-- ============================================================
-- DFN Control
-- PHASE 3 — BATCH 1
-- PROJECT ADMINISTRATION + ARCHIVING
--
-- Platform-plane project registry administration.
--
-- IMPORTANT:
-- - Superadmin may administer project metadata.
-- - Superadmin does NOT receive project.view.
-- - Superadmin does NOT receive portfolio access.
-- - Superadmin does NOT receive financial access.
-- - No browser direct INSERT / UPDATE / DELETE on projects.
-- - No hard-delete RPC.
-- - Archiving preserves memberships, audit history and future
--   module data.
-- ============================================================


-- ============================================================
-- 1. PROJECT ARCHIVE METADATA
-- ============================================================

ALTER TABLE public.projects
  ADD COLUMN archived_at timestamptz,
  ADD COLUMN archived_by uuid
    REFERENCES public.profiles(id)
    ON DELETE SET NULL,
  ADD COLUMN archive_reason text;


ALTER TABLE public.projects
  ADD CONSTRAINT projects_archive_reason_not_blank
  CHECK (
    archive_reason IS NULL
    OR length(btrim(archive_reason)) > 0
  );


ALTER TABLE public.projects
  ADD CONSTRAINT projects_archive_reason_length
  CHECK (
    archive_reason IS NULL
    OR char_length(archive_reason) <= 500
  );


-- Active projects may not retain archive metadata.
-- Archived projects must have archived_at.
--
-- archived_by is intentionally nullable because the actor profile
-- could later be deleted and the FK uses ON DELETE SET NULL.

ALTER TABLE public.projects
  ADD CONSTRAINT projects_archive_state_check
  CHECK (
    (
      is_active = true
      AND archived_at IS NULL
      AND archived_by IS NULL
      AND archive_reason IS NULL
    )
    OR
    (
      is_active = false
      AND archived_at IS NOT NULL
    )
  );


CREATE INDEX projects_archive_state_idx
ON public.projects (
  organization_id,
  is_active,
  archived_at DESC
);


-- ============================================================
-- 2. ADMIN AUTHORIZATION HELPER
--
-- Phase 3 Batch 1 deliberately allows PLATFORM Superadmin only.
--
-- This is NOT project/business authority.
-- ============================================================

CREATE FUNCTION private.can_administer_project_registry()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT private.is_superadmin();
$$;


REVOKE ALL
ON FUNCTION private.can_administer_project_registry()
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION private.can_administer_project_registry()
TO authenticated, service_role;


-- ============================================================
-- 3. PROJECT ADMIN CONTEXT
--
-- Administrative metadata only.
--
-- Does NOT expose:
--   project memberships
--   financial data
--   reports
--   materials
--   audit rows
--   business authorization internals
-- ============================================================

CREATE FUNCTION public.get_project_admin_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_organizations jsonb;
  v_business_units jsonb;
  v_projects jsonb;
BEGIN

  v_user_id := auth.uid();


  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'Authentication required.'
      USING ERRCODE = '42501';
  END IF;


  IF NOT private.can_administer_project_registry() THEN
    RAISE EXCEPTION
      'Project administration is not permitted.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Organization registry
  -- ----------------------------------------------------------

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'legal_name', o.legal_name,
        'country', o.country,
        'timezone', o.timezone,
        'default_currency', o.default_currency,
        'is_active', o.is_active
      )
      ORDER BY o.name
    ),
    '[]'::jsonb
  )
  INTO v_organizations
  FROM public.organizations o;


  -- ----------------------------------------------------------
  -- Business-unit registry
  -- ----------------------------------------------------------

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', bu.id,
        'organization_id', bu.organization_id,
        'code', bu.code,
        'name', bu.name,
        'is_active', bu.is_active
      )
      ORDER BY bu.organization_id, bu.name
    ),
    '[]'::jsonb
  )
  INTO v_business_units
  FROM public.business_units bu;


  -- ----------------------------------------------------------
  -- Project registry
  -- ----------------------------------------------------------

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'organization_id', p.organization_id,
        'business_unit_id', p.business_unit_id,
        'code', p.code,
        'name', p.name,
        'client_name', p.client_name,
        'location_label', p.location_label,
        'status', p.status,
        'start_date', p.start_date,
        'end_date', p.end_date,
        'is_active', p.is_active,
        'archived_at', p.archived_at,
        'archived_by', p.archived_by,
        'archive_reason', p.archive_reason,
        'created_at', p.created_at,
        'updated_at', p.updated_at
      )
      ORDER BY
        p.is_active DESC,
        p.name
    ),
    '[]'::jsonb
  )
  INTO v_projects
  FROM public.projects p;


  RETURN jsonb_build_object(
    'version', 1,
    'organizations', v_organizations,
    'business_units', v_business_units,
    'projects', v_projects
  );

END;
$$;


-- ============================================================
-- 4. CREATE PROJECT
--
-- Creates registry metadata only.
--
-- It does NOT:
--   create memberships
--   grant project.view
--   create financial rows
--   give creator business authority
-- ============================================================

CREATE FUNCTION public.admin_create_project(
  p_organization_id uuid,
  p_code text,
  p_name text,
  p_business_unit_id uuid DEFAULT NULL,
  p_client_name text DEFAULT NULL,
  p_location_label text DEFAULT NULL,
  p_status text DEFAULT 'planning',
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;

  v_code text;
  v_name text;
  v_client_name text;
  v_location_label text;
  v_status text;

  v_project public.projects;
BEGIN

  v_user_id := auth.uid();


  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'Authentication required.'
      USING ERRCODE = '42501';
  END IF;


  IF NOT private.can_administer_project_registry() THEN
    RAISE EXCEPTION
      'Project administration is not permitted.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Normalize input
  -- ----------------------------------------------------------

  v_code :=
    upper(
      NULLIF(
        btrim(p_code),
        ''
      )
    );

  v_name :=
    NULLIF(
      btrim(p_name),
      ''
    );

  v_client_name :=
    NULLIF(
      btrim(p_client_name),
      ''
    );

  v_location_label :=
    NULLIF(
      btrim(p_location_label),
      ''
    );

  v_status :=
    lower(
      NULLIF(
        btrim(p_status),
        ''
      )
    );


  -- ----------------------------------------------------------
  -- Guards
  -- ----------------------------------------------------------

  IF v_code IS NULL THEN
    RAISE EXCEPTION
      'Project code is required.'
      USING ERRCODE = '22023';
  END IF;


  IF v_name IS NULL THEN
    RAISE EXCEPTION
      'Project name is required.'
      USING ERRCODE = '22023';
  END IF;


  IF char_length(v_code) > 50 THEN
    RAISE EXCEPTION
      'Project code is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF char_length(v_name) > 200 THEN
    RAISE EXCEPTION
      'Project name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_client_name IS NOT NULL
    AND char_length(v_client_name) > 200
  THEN
    RAISE EXCEPTION
      'Client name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_location_label IS NOT NULL
    AND char_length(v_location_label) > 300
  THEN
    RAISE EXCEPTION
      'Location label is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF v_status NOT IN (
    'planning',
    'active',
    'on_hold',
    'completed',
    'cancelled'
  ) THEN
    RAISE EXCEPTION
      'Invalid project status.'
      USING ERRCODE = '22023';
  END IF;


  IF
    p_start_date IS NOT NULL
    AND p_end_date IS NOT NULL
    AND p_end_date < p_start_date
  THEN
    RAISE EXCEPTION
      'Project end date cannot be before start date.'
      USING ERRCODE = '22023';
  END IF;


  IF NOT EXISTS (
    SELECT 1
    FROM public.organizations o
    WHERE o.id = p_organization_id
      AND o.is_active = true
  ) THEN
    RAISE EXCEPTION
      'Active organization not found.'
      USING ERRCODE = '22023';
  END IF;


  IF
    p_business_unit_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.business_units bu
      WHERE bu.id = p_business_unit_id
        AND bu.organization_id = p_organization_id
        AND bu.is_active = true
    )
  THEN
    RAISE EXCEPTION
      'Active business unit does not belong to organization.'
      USING ERRCODE = '22023';
  END IF;


  -- ----------------------------------------------------------
  -- Insert
  -- ----------------------------------------------------------

  INSERT INTO public.projects (
    organization_id,
    business_unit_id,
    code,
    name,
    client_name,
    location_label,
    status,
    start_date,
    end_date,
    is_active
  )
  VALUES (
    p_organization_id,
    p_business_unit_id,
    v_code,
    v_name,
    v_client_name,
    v_location_label,
    v_status,
    p_start_date,
    p_end_date,
    true
  )
  RETURNING *
  INTO v_project;


  -- ----------------------------------------------------------
  -- Audit
  -- ----------------------------------------------------------

  PERFORM private.write_audit_log(
    p_scope           => 'organization',
    p_entity_type     => 'project',
    p_action          => 'project.admin_created',
    p_organization_id => v_project.organization_id,
    p_entity_key      => v_project.id::text,

    p_new_data => jsonb_build_object(
      'id', v_project.id,
      'code', v_project.code,
      'name', v_project.name,
      'business_unit_id', v_project.business_unit_id,
      'client_name', v_project.client_name,
      'location_label', v_project.location_label,
      'status', v_project.status,
      'start_date', v_project.start_date,
      'end_date', v_project.end_date
    ),

    p_metadata => jsonb_build_object(
      'administration_plane', 'platform',
      'granted_business_authority', false
    ),

    p_source => 'browser-rpc'
  );


  RETURN jsonb_build_object(
    'id', v_project.id,
    'organization_id', v_project.organization_id,
    'business_unit_id', v_project.business_unit_id,
    'code', v_project.code,
    'name', v_project.name,
    'client_name', v_project.client_name,
    'location_label', v_project.location_label,
    'status', v_project.status,
    'start_date', v_project.start_date,
    'end_date', v_project.end_date,
    'is_active', v_project.is_active,
    'archived_at', v_project.archived_at,
    'archive_reason', v_project.archive_reason
  );

END;
$$;


-- ============================================================
-- 5. UPDATE PROJECT
--
-- Only active projects can be edited through this RPC.
--
-- Immutable here:
--   id
--   organization_id
--   is_active
--   archive metadata
-- ============================================================

CREATE FUNCTION public.admin_update_project(
  p_project_id uuid,
  p_code text,
  p_name text,
  p_business_unit_id uuid DEFAULT NULL,
  p_client_name text DEFAULT NULL,
  p_location_label text DEFAULT NULL,
  p_status text DEFAULT 'planning',
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;

  v_code text;
  v_name text;
  v_client_name text;
  v_location_label text;
  v_status text;

  v_old public.projects;
  v_new public.projects;
BEGIN

  v_user_id := auth.uid();


  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'Authentication required.'
      USING ERRCODE = '42501';
  END IF;


  IF NOT private.can_administer_project_registry() THEN
    RAISE EXCEPTION
      'Project administration is not permitted.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Lock active project
  -- ----------------------------------------------------------

  SELECT *
  INTO v_old
  FROM public.projects p
  WHERE p.id = p_project_id
    AND p.is_active = true
  FOR UPDATE;


  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Active project not found.'
      USING ERRCODE = '22023';
  END IF;


  -- ----------------------------------------------------------
  -- Normalize
  -- ----------------------------------------------------------

  v_code :=
    upper(
      NULLIF(
        btrim(p_code),
        ''
      )
    );

  v_name :=
    NULLIF(
      btrim(p_name),
      ''
    );

  v_client_name :=
    NULLIF(
      btrim(p_client_name),
      ''
    );

  v_location_label :=
    NULLIF(
      btrim(p_location_label),
      ''
    );

  v_status :=
    lower(
      NULLIF(
        btrim(p_status),
        ''
      )
    );


  -- ----------------------------------------------------------
  -- Guards
  -- ----------------------------------------------------------

  IF v_code IS NULL THEN
    RAISE EXCEPTION
      'Project code is required.'
      USING ERRCODE = '22023';
  END IF;


  IF v_name IS NULL THEN
    RAISE EXCEPTION
      'Project name is required.'
      USING ERRCODE = '22023';
  END IF;


  IF char_length(v_code) > 50 THEN
    RAISE EXCEPTION
      'Project code is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF char_length(v_name) > 200 THEN
    RAISE EXCEPTION
      'Project name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_client_name IS NOT NULL
    AND char_length(v_client_name) > 200
  THEN
    RAISE EXCEPTION
      'Client name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_location_label IS NOT NULL
    AND char_length(v_location_label) > 300
  THEN
    RAISE EXCEPTION
      'Location label is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF v_status NOT IN (
    'planning',
    'active',
    'on_hold',
    'completed',
    'cancelled'
  ) THEN
    RAISE EXCEPTION
      'Invalid project status.'
      USING ERRCODE = '22023';
  END IF;


  IF
    p_start_date IS NOT NULL
    AND p_end_date IS NOT NULL
    AND p_end_date < p_start_date
  THEN
    RAISE EXCEPTION
      'Project end date cannot be before start date.'
      USING ERRCODE = '22023';
  END IF;


  IF
    p_business_unit_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.business_units bu
      WHERE bu.id = p_business_unit_id
        AND bu.organization_id = v_old.organization_id
        AND bu.is_active = true
    )
  THEN
    RAISE EXCEPTION
      'Active business unit does not belong to project organization.'
      USING ERRCODE = '22023';
  END IF;


  -- ----------------------------------------------------------
  -- Update
  -- ----------------------------------------------------------

  UPDATE public.projects
  SET
    business_unit_id = p_business_unit_id,
    code = v_code,
    name = v_name,
    client_name = v_client_name,
    location_label = v_location_label,
    status = v_status,
    start_date = p_start_date,
    end_date = p_end_date
  WHERE id = p_project_id
  RETURNING *
  INTO v
