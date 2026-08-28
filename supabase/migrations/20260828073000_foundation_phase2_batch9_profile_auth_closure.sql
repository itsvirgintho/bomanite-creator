-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 9
-- Profile RPCs + Authorization Context + Foundation Closure
--
-- FINAL FOUNDATION MIGRATION
--
-- Creates:
--   1. public.update_own_profile(...)
--   2. public.get_my_authorization_context()
--
-- Security principles:
--   - browser never gets direct profile UPDATE
--   - users may modify ONLY their own safe profile fields
--   - role / financial / employee / active-state fields remain
--     outside browser control
--   - authorization internals remain private
--   - Superadmin remains separate from business authority
--   - financial UI flags use the authoritative same-path helper
--   - all browser-callable functions use auth.uid()
--   - SECURITY DEFINER + search_path=''
-- ============================================================


-- ============================================================
-- 1. public.update_own_profile(...)
--
-- Safe self-service profile mutation.
--
-- Browser may change ONLY:
--   first_name
--   last_name
--   phone
--   avatar_path
--
-- Browser may NOT change:
--   job_title
--   employee_code
--   is_active
--   organization role
--   project role
--   financial levels
--   permissions
-- ============================================================

CREATE FUNCTION public.update_own_profile(
  p_first_name  text,
  p_last_name   text,
  p_phone       text,
  p_avatar_path text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;

  v_old_first_name  text;
  v_old_last_name   text;
  v_old_phone       text;
  v_old_avatar_path text;

  v_new_first_name  text;
  v_new_last_name   text;
  v_new_phone       text;
  v_new_avatar_path text;

  v_changed_fields jsonb := '[]'::jsonb;

  v_result jsonb;
BEGIN

  -- ----------------------------------------------------------
  -- Authenticated identity only.
  -- ----------------------------------------------------------

  v_user_id := (SELECT auth.uid());


  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'Authentication required.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Normalize user-editable values.
  --
  -- Empty / whitespace-only input becomes NULL.
  -- ----------------------------------------------------------

  v_new_first_name :=
    NULLIF(
      btrim(p_first_name),
      ''
    );

  v_new_last_name :=
    NULLIF(
      btrim(p_last_name),
      ''
    );

  v_new_phone :=
    NULLIF(
      btrim(p_phone),
      ''
    );

  v_new_avatar_path :=
    NULLIF(
      btrim(p_avatar_path),
      ''
    );


  -- ----------------------------------------------------------
  -- Input size guards.
  --
  -- These protect the browser RPC without changing the broader
  -- administrative data model.
  -- ----------------------------------------------------------

  IF
    v_new_first_name IS NOT NULL
    AND char_length(v_new_first_name) > 100
  THEN
    RAISE EXCEPTION
      'First name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_new_last_name IS NOT NULL
    AND char_length(v_new_last_name) > 100
  THEN
    RAISE EXCEPTION
      'Last name is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_new_phone IS NOT NULL
    AND char_length(v_new_phone) > 64
  THEN
    RAISE EXCEPTION
      'Phone is too long.'
      USING ERRCODE = '22001';
  END IF;


  IF
    v_new_avatar_path IS NOT NULL
    AND char_length(v_new_avatar_path) > 512
  THEN
    RAISE EXCEPTION
      'Avatar path is too long.'
      USING ERRCODE = '22001';
  END IF;


  -- ----------------------------------------------------------
  -- Lock and read current active profile.
  --
  -- Inactive profiles cannot use self-service mutation.
  -- ----------------------------------------------------------

  SELECT
    p.first_name,
    p.last_name,
    p.phone,
    p.avatar_path

  INTO
    v_old_first_name,
    v_old_last_name,
    v_old_phone,
    v_old_avatar_path

  FROM public.profiles p

  WHERE p.id = v_user_id
    AND p.is_active = true

  FOR UPDATE;


  IF NOT FOUND THEN
    RAISE EXCEPTION
      'Active profile not found.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Determine changed fields.
  --
  -- Audit metadata contains field names only.
  -- It intentionally does NOT duplicate personal values into
  -- the audit payload.
  -- ----------------------------------------------------------

  IF v_old_first_name IS DISTINCT FROM v_new_first_name THEN
    v_changed_fields :=
      v_changed_fields
      || jsonb_build_array('first_name');
  END IF;


  IF v_old_last_name IS DISTINCT FROM v_new_last_name THEN
    v_changed_fields :=
      v_changed_fields
      || jsonb_build_array('last_name');
  END IF;


  IF v_old_phone IS DISTINCT FROM v_new_phone THEN
    v_changed_fields :=
      v_changed_fields
      || jsonb_build_array('phone');
  END IF;


  IF v_old_avatar_path IS DISTINCT FROM v_new_avatar_path THEN
    v_changed_fields :=
      v_changed_fields
      || jsonb_build_array('avatar_path');
  END IF;


  -- ----------------------------------------------------------
  -- Only write when something actually changed.
  -- ----------------------------------------------------------

  IF jsonb_array_length(v_changed_fields) > 0 THEN

    UPDATE public.profiles
    SET
      first_name = v_new_first_name,
      last_name = v_new_last_name,
      phone = v_new_phone,
      avatar_path = v_new_avatar_path

    WHERE id = v_user_id;


    -- --------------------------------------------------------
    -- Trusted audit entry.
    --
    -- No old/new personal values are stored here.
    -- --------------------------------------------------------

    PERFORM private.write_audit_log(
      p_scope       => 'platform',
      p_entity_type => 'profile',
      p_action      => 'profile.self_updated',
      p_entity_key  => v_user_id::text,

      p_metadata    => jsonb_build_object(
        'changed_fields',
        v_changed_fields
      ),

      p_source      => 'browser-rpc'
    );

  END IF;


  -- ----------------------------------------------------------
  -- Return only safe own-profile context.
  -- ----------------------------------------------------------

  SELECT jsonb_build_object(
    'id',
    p.id,

    'first_name',
    p.first_name,

    'last_name',
    p.last_name,

    'phone',
    p.phone,

    'avatar_path',
    p.avatar_path,

    'job_title',
    p.job_title,

    'employee_code',
    p.employee_code,

    'updated_at',
    p.updated_at
  )

  INTO v_result

  FROM public.profiles p

  WHERE p.id = v_user_id
    AND p.is_active = true;


  RETURN v_result;

END;
$$;


-- ============================================================
-- 2. update_own_profile privileges
-- ============================================================

REVOKE ALL
ON FUNCTION public.update_own_profile(
  text,
  text,
  text,
  text
)
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION public.update_own_profile(
  text,
  text,
  text,
  text
)
TO authenticated;


-- ============================================================
-- 3. public.get_my_authorization_context()
--
-- Safe browser authorization context.
--
-- Does NOT expose:
--   permissions table
--   role_permissions table
--   permission overrides table
--   platform_admins table
--   other users' authorization internals
--
-- It returns only the effective context of auth.uid().
--
-- Financial flags are authoritative.
-- The frontend MUST NOT infer financial access merely from
-- financial_level.
-- ============================================================

CREATE FUNCTION public.get_my_authorization_context()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;

  v_profile       jsonb;
  v_organizations jsonb;
  v_projects      jsonb;

  v_result        jsonb;
BEGIN

  -- ----------------------------------------------------------
  -- Authenticated identity.
  -- ----------------------------------------------------------

  v_user_id := (SELECT auth.uid());


  IF v_user_id IS NULL THEN
    RAISE EXCEPTION
      'Authentication required.'
      USING ERRCODE = '42501';
  END IF;


  -- ----------------------------------------------------------
  -- Own active profile.
  --
  -- Inactive profiles receive no application authorization
  -- context at all.
  -- ----------------------------------------------------------

  SELECT jsonb_build_object(
    'id',
    p.id,

    'first_name',
    p.first_name,

    'last_name',
    p.last_name,

    'phone',
    p.phone,

    'avatar_path',
    p.avatar_path,

    'job_title',
    p.job_title,

    'employee_code',
    p.employee_code
  )

  INTO v_profile

  FROM public.profiles p

  WHERE p.id = v_user_id
    AND p.is_active = true;


  IF v_profile IS NULL THEN
    RAISE EXCEPTION
      'Active profile not found.'
      USING ERRCODE = '42501';
  END IF;


  -- ==========================================================
  -- 4. Accessible organizations
  --
  -- Important:
  -- A passive organization membership by itself does NOT expose
  -- organization business data.
  --
  -- Therefore this RPC follows the same
  -- private.can_access_organization() decision used by RLS.
  -- ==========================================================

  SELECT COALESCE(
    jsonb_agg(
      q.organization_json
      ORDER BY q.organization_name
    ),
    '[]'::jsonb
  )

  INTO v_organizations

  FROM (

    SELECT
      org.name AS organization_name,

      jsonb_build_object(
        'id',
        org.id,

        'name',
        org.name,

        'legal_name',
        org.legal_name,

        'country',
        org.country,

        'timezone',
        org.timezone,

        'default_currency',
        org.default_currency,


        -- ----------------------------------------------------
        -- Own organization membership only.
        -- ----------------------------------------------------

        'membership',
        jsonb_build_object(
          'role',
          CASE
            WHEN r.id IS NOT NULL
             AND r.is_active = true
            THEN
              jsonb_build_object(
                'id',
                r.id,

                'code',
                r.code,

                'name',
                r.name
              )

            ELSE NULL
          END,

          'financial_level',
          om.financial_level
        ),


        -- ----------------------------------------------------
        -- Effective organization-scoped business permissions.
        --
        -- admin.* is intentionally omitted.
        -- Superadmin is represented separately.
        -- ----------------------------------------------------

        'permissions',
        COALESCE(
          (
            SELECT jsonb_agg(
              perm.code
              ORDER BY perm.code
            )

            FROM public.permissions perm

            WHERE perm.is_active = true

              AND perm.code NOT LIKE 'admin.%'

              AND private.has_org_permission(
                org.id,
                perm.code
              )
          ),
          '[]'::jsonb
        )
      ) AS organization_json

    FROM public.organization_members om

    JOIN public.organizations org
      ON org.id = om.organization_id

    LEFT JOIN public.roles r
      ON r.id = om.role_id

    WHERE om.user_id = v_user_id
      AND om.is_active = true
      AND org.is_active = true

      AND private.can_access_organization(
        org.id
      )

  ) q;


  -- ==========================================================
  -- 5. Accessible projects
  --
  -- Project visibility follows exactly can_access_project().
  --
  -- Projects may be visible through:
  --   A. direct project membership + project.view
  --   B. organization portfolio.view
  --
  -- Direct project permissions are returned separately from
  -- organization permissions.
  -- ==========================================================

  SELECT COALESCE(
    jsonb_agg(
      q.project_json
      ORDER BY q.project_name
    ),
    '[]'::jsonb
  )

  INTO v_projects

  FROM (

    SELECT
      proj.name AS project_name,

      jsonb_build_object(
        'id',
        proj.id,

        'organization_id',
        proj.organization_id,

        'business_unit_id',
        proj.business_unit_id,

        'code',
        proj.code,

        'name',
        proj.name,

        'client_name',
        proj.client_name,

        'location_label',
        proj.location_label,

        'status',
        proj.status,

        'start_date',
        proj.start_date,

        'end_date',
        proj.end_date,


        -- ----------------------------------------------------
        -- Valid direct project membership only.
        --
        -- A portfolio-only Director may legitimately receive
        -- NULL here.
        -- ----------------------------------------------------

        'direct_membership',
        CASE
          WHEN private.is_project_member(
            proj.id
          )
          THEN
            jsonb_build_object(
              'role',
              CASE
                WHEN project_role.id IS NOT NULL
                 AND project_role.is_active = true
                THEN
                  jsonb_build_object(
                    'id',
                    project_role.id,

                    'code',
                    project_role.code,

                    'name',
                    project_role.name
                  )

                ELSE NULL
              END,

              'financial_level',
              pm.financial_level
            )

          ELSE NULL
        END,


        -- ----------------------------------------------------
        -- Effective PROJECT-path permissions.
        --
        -- Includes project-role permissions and applicable
        -- ALLOW/DENY override resolution through the existing
        -- authorization helper.
        --
        -- admin.* is intentionally omitted.
        -- ----------------------------------------------------

        'permissions',
        COALESCE(
          (
            SELECT jsonb_agg(
              perm.code
              ORDER BY perm.code
            )

            FROM public.permissions perm

            WHERE perm.is_active = true

              AND perm.code NOT LIKE 'admin.%'

              AND private.has_project_permission(
                proj.id,
                perm.code
              )
          ),
          '[]'::jsonb
        ),


        -- ----------------------------------------------------
        -- AUTHORITATIVE financial UI access.
        --
        -- These booleans MUST be used instead of inferring
        -- access from financial_level.
        --
        -- The helper preserves the same-path rule:
        -- level + permission must come from the same authority
        -- path.
        -- ----------------------------------------------------

        'financial_access',
        jsonb_build_object(
          'cost',
          private.can_read_financial_class(
            proj.id,
            2::smallint,
            'financial.cost_view'
          ),

          'contract',
          private.can_read_financial_class(
            proj.id,
            3::smallint,
            'financial.contract_view'
          ),

          'margin',
          private.can_read_financial_class(
            proj.id,
            4::smallint,
            'financial.margin_view'
          ),

          'collection',
          private.can_read_financial_class(
            proj.id,
            4::smallint,
            'financial.collection_view'
          )
        )
      ) AS project_json

    FROM public.projects proj

    LEFT JOIN public.project_members pm
      ON pm.project_id = proj.id
     AND pm.user_id = v_user_id
     AND pm.is_active = true

    LEFT JOIN public.roles project_role
      ON project_role.id = pm.role_id

    WHERE private.can_access_project(
      proj.id
    )

  ) q;


  -- ==========================================================
  -- 6. Final context
  --
  -- Superadmin is independent.
  --
  -- A Superadmin with no business authority receives:
  --   is_superadmin = true
  --   organizations = []
  --   projects = []
  -- ==========================================================

  v_result :=
    jsonb_build_object(
      'version',
      1,

      'profile',
      v_profile,

      'is_superadmin',
      private.is_superadmin(),

      'organizations',
      v_organizations,

      'projects',
      v_projects
    );


  RETURN v_result;

END;
$$;


-- ============================================================
-- 7. Authorization-context privileges
-- ============================================================

REVOKE ALL
ON FUNCTION public.get_my_authorization_context()
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION public.get_my_authorization_context()
TO authenticated;


-- ============================================================
-- 8. Foundation security closure assertions
-- ============================================================

DO $$
DECLARE
  v_table text;
BEGIN

  -- ==========================================================
  -- RPC existence
  -- ==========================================================

  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'
      AND p.proname = 'update_own_profile'

      AND pg_get_function_identity_arguments(
        p.oid
      ) =
        'p_first_name text, p_last_name text, p_phone text, p_avatar_path text'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: update_own_profile missing.';
  END IF;


  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'
      AND p.proname =
        'get_my_authorization_context'

      AND pg_get_function_identity_arguments(
        p.oid
      ) = ''
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authorization context RPC missing.';
  END IF;


  -- ==========================================================
  -- Both public RPCs SECURITY DEFINER
  -- ==========================================================

  IF (
    SELECT count(*)

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'

      AND p.proname IN (
        'update_own_profile',
        'get_my_authorization_context'
      )

      AND p.prosecdef = true
  ) <> 2 THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: public RPC SECURITY DEFINER mismatch.';
  END IF;


  -- ==========================================================
  -- Both public RPCs search_path=''
  -- ==========================================================

  IF (
    SELECT count(*)

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'public'

      AND p.proname IN (
        'update_own_profile',
        'get_my_authorization_context'
      )

      AND p.proconfig IS NOT NULL

      AND 'search_path=""' = ANY(
        p.proconfig
      )
  ) <> 2 THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: RPC search_path not locked.';
  END IF;


  -- ==========================================================
  -- authenticated EXECUTE
  -- ==========================================================

  IF NOT has_function_privilege(
    'authenticated',
    'public.update_own_profile(text,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authenticated cannot execute update_own_profile.';
  END IF;


  IF NOT has_function_privilege(
    'authenticated',
    'public.get_my_authorization_context()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authenticated cannot execute authorization context.';
  END IF;


  -- ==========================================================
  -- anon cannot execute either RPC
  -- ==========================================================

  IF has_function_privilege(
    'anon',
    'public.update_own_profile(text,text,text,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: anon can execute update_own_profile.';
  END IF;


  IF has_function_privilege(
    'anon',
    'public.get_my_authorization_context()',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: anon can execute authorization context.';
  END IF;


  -- ==========================================================
  -- PUBLIC pseudo-role cannot execute either RPC
  -- ==========================================================

  IF EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    CROSS JOIN LATERAL aclexplode(
      COALESCE(
        p.proacl,
        acldefault(
          'f',
          p.proowner
        )
      )
    ) AS acl

    WHERE n.nspname = 'public'

      AND p.proname IN (
        'update_own_profile',
        'get_my_authorization_context'
      )

      AND acl.grantee = 0

      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: PUBLIC can execute a browser RPC.';
  END IF;


  -- ==========================================================
  -- Browser still has NO direct profiles mutation.
  --
  -- Self profile changes must go through update_own_profile().
  -- ==========================================================

  IF
    has_table_privilege(
      'authenticated',
      'public.profiles',
      'INSERT'
    )

    OR has_table_privilege(
      'authenticated',
      'public.profiles',
      'UPDATE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.profiles',
      'DELETE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: browser has direct profile mutation.';
  END IF;


  -- ==========================================================
  -- Internal authorization tables still unreadable.
  -- ==========================================================

  IF
    has_table_privilege(
      'authenticated',
      'public.permissions',
      'SELECT'
    )

    OR has_table_privilege(
      'authenticated',
      'public.role_permissions',
      'SELECT'
    )

    OR has_table_privilege(
      'authenticated',
      'public.project_member_permission_overrides',
      'SELECT'
    )
  THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authorization internals exposed.';
  END IF;


  -- ==========================================================
  -- No business role may hold admin.*.
  -- ==========================================================

  IF EXISTS (
    SELECT 1

    FROM public.role_permissions rp

    JOIN public.permissions p
      ON p.id = rp.permission_id

    WHERE p.code LIKE 'admin.%'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: admin permission assigned to business role.';
  END IF;


  -- ==========================================================
  -- audit.view remains unassigned at Foundation closure.
  -- ==========================================================

  IF EXISTS (
    SELECT 1

    FROM public.role_permissions rp

    JOIN public.permissions p
      ON p.id = rp.permission_id

    WHERE p.code = 'audit.view'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: audit.view unexpectedly assigned.';
  END IF;


  -- ==========================================================
  -- authenticated private schema access:
  --
  -- USAGE is needed because RLS policies invoke exact private
  -- authorization helpers.
  --
  -- CREATE must remain blocked.
  -- ==========================================================

  IF NOT has_schema_privilege(
    'authenticated',
    'private',
    'USAGE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authenticated private schema USAGE missing.';
  END IF;


  IF has_schema_privilege(
    'authenticated',
    'private',
    'CREATE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: authenticated can CREATE in private schema.';
  END IF;


  -- ==========================================================
  -- anon has no private schema access.
  -- ==========================================================

  IF
    has_schema_privilege(
      'anon',
      'private',
      'USAGE'
    )

    OR has_schema_privilege(
      'anon',
      'private',
      'CREATE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: anon private schema access detected.';
  END IF;


  -- ==========================================================
  -- FOUNDATION-WIDE:
  -- browser may not directly mutate any protected table.
  --
  -- Future browser writes must happen through deliberately
  -- designed trusted RPCs / server mutations.
  -- ==========================================================

  FOREACH v_table IN ARRAY ARRAY[
    'organizations',
    'business_units',
    'profiles',

    'roles',
    'permissions',
    'role_permissions',

    'organization_members',
    'projects',
    'project_members',
    'project_member_permission_overrides',

    'project_cost_financials',
    'project_contract_financials',
    'project_executive_financials',

    'project_locations',
    'audit_logs'
  ]
  LOOP

    IF
      has_table_privilege(
        'authenticated',
        format(
          'public.%I',
          v_table
        ),
        'INSERT'
      )

      OR has_table_privilege(
        'authenticated',
        format(
          'public.%I',
          v_table
        ),
        'UPDATE'
      )

      OR has_table_privilege(
        'authenticated',
        format(
          'public.%I',
          v_table
        ),
        'DELETE'
      )

      OR has_table_privilege(
        'authenticated',
        format(
          'public.%I',
          v_table
        ),
        'TRUNCATE'
      )
    THEN
      RAISE EXCEPTION
        'Batch 9 validation failed: authenticated mutation privilege detected on %.',
        v_table;
    END IF;

  END LOOP;


  -- ==========================================================
  -- FOUNDATION-WIDE:
  -- anon may not SELECT any protected business table.
  -- ==========================================================

  FOREACH v_table IN ARRAY ARRAY[
    'organizations',
    'business_units',
    'profiles',

    'roles',
    'permissions',
    'role_permissions',

    'organization_members',
    'projects',
    'project_members',
    'project_member_permission_overrides',

    'project_cost_financials',
    'project_contract_financials',
    'project_executive_financials',

    'project_locations',
    'audit_logs'
  ]
  LOOP

    IF has_table_privilege(
      'anon',
      format(
        'public.%I',
        v_table
      ),
      'SELECT'
    )
    THEN
      RAISE EXCEPTION
        'Batch 9 validation failed: anon SELECT detected on %.',
        v_table;
    END IF;

  END LOOP;


  -- ==========================================================
  -- Audit writer remains protected.
  -- ==========================================================

  IF has_function_privilege(
    'authenticated',
    'private.write_audit_log(text,text,text,uuid,uuid,text,jsonb,jsonb,jsonb,text,text,uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: browser can execute audit writer.';
  END IF;


  -- ==========================================================
  -- Authorization helper remains protected from anon.
  -- ==========================================================

  IF has_function_privilege(
    'anon',
    'private.can_read_financial_class(uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 9 validation failed: anon can execute financial helper.';
  END IF;

END;
$$;
