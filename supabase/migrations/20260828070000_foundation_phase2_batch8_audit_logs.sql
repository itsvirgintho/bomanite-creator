-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 8
-- Immutable Audit Logs
--
-- Goals:
--   - append-only audit trail
--   - no browser writes
--   - no direct service-role writes
--   - trusted writes through private.write_audit_log()
--   - actor identity snapshot
--   - platform / organization / project scopes
--   - old/new JSONB snapshots
--   - Superadmin global audit visibility
--   - organization audit visibility requires audit.view
--   - financial audit rows additionally require the same
--     authoritative F2/F3/F4 financial authorization
--
-- IMPORTANT:
--   audit.view itself is NOT assigned to any role here.
-- ============================================================


-- ============================================================
-- 1. public.audit_logs
-- ============================================================

CREATE TABLE public.audit_logs (
  id                           uuid
                               PRIMARY KEY
                               DEFAULT gen_random_uuid(),

  occurred_at                  timestamptz
                               NOT NULL
                               DEFAULT now(),


  -- ==========================================================
  -- Scope
  -- ==========================================================

  scope                        text
                               NOT NULL,

  organization_id              uuid
                               NULL
                               REFERENCES public.organizations (id)
                               ON DELETE RESTRICT,

  project_id                   uuid
                               NULL,


  -- ==========================================================
  -- Actor
  --
  -- actor_user_id can become NULL if the user is deleted.
  -- Snapshot fields intentionally survive.
  -- ==========================================================

  actor_user_id                uuid
                               NULL
                               REFERENCES public.profiles (id)
                               ON DELETE SET NULL,

  actor_name_snapshot          text
                               NULL,

  actor_employee_code_snapshot text
                               NULL,


  -- ==========================================================
  -- Audited entity/action
  -- ==========================================================

  entity_type                  text
                               NOT NULL,

  entity_key                   text
                               NULL,

  action                       text
                               NOT NULL,


  -- ==========================================================
  -- State snapshots
  -- ==========================================================

  old_data                     jsonb
                               NULL,

  new_data                     jsonb
                               NULL,

  metadata                     jsonb
                               NOT NULL
                               DEFAULT '{}'::jsonb,


  -- ==========================================================
  -- Request/source tracing
  -- ==========================================================

  source                       text
                               NOT NULL
                               DEFAULT 'server',

  request_id                   text
                               NULL,


  -- ==========================================================
  -- Financial classification
  --
  -- 0 = non-financial audit record
  -- 2 = F2 cost
  -- 3 = F3 contract
  -- 4 = F4 margin / collection
  --
  -- F1 is intentionally not modeled as one of the protected
  -- project financial classes because the current authoritative
  -- helper defines only F2/F3/F4 protected classes.
  -- ==========================================================

  required_financial_level     smallint
                               NOT NULL
                               DEFAULT 0,

  financial_permission_code    text
                               NULL,


  -- ==========================================================
  -- Project must belong to organization
  -- ==========================================================

  CONSTRAINT audit_logs_project_org_fkey
    FOREIGN KEY (
      project_id,
      organization_id
    )
    REFERENCES public.projects (
      id,
      organization_id
    )
    ON DELETE RESTRICT,


  -- ==========================================================
  -- Scope integrity
  -- ==========================================================

  CONSTRAINT audit_logs_scope_check
    CHECK (
      (
        scope = 'platform'
        AND organization_id IS NULL
        AND project_id IS NULL
      )

      OR

      (
        scope = 'organization'
        AND organization_id IS NOT NULL
        AND project_id IS NULL
      )

      OR

      (
        scope = 'project'
        AND organization_id IS NOT NULL
        AND project_id IS NOT NULL
      )
    ),


  -- ==========================================================
  -- Text integrity
  -- ==========================================================

  CONSTRAINT audit_logs_entity_type_not_blank
    CHECK (
      length(btrim(entity_type)) > 0
    ),

  CONSTRAINT audit_logs_entity_key_not_blank
    CHECK (
      entity_key IS NULL
      OR length(btrim(entity_key)) > 0
    ),

  CONSTRAINT audit_logs_action_not_blank
    CHECK (
      length(btrim(action)) > 0
    ),

  CONSTRAINT audit_logs_source_not_blank
    CHECK (
      length(btrim(source)) > 0
    ),

  CONSTRAINT audit_logs_request_id_not_blank
    CHECK (
      request_id IS NULL
      OR length(btrim(request_id)) > 0
    ),

  CONSTRAINT audit_logs_actor_name_not_blank
    CHECK (
      actor_name_snapshot IS NULL
      OR length(btrim(actor_name_snapshot)) > 0
    ),

  CONSTRAINT audit_logs_actor_employee_code_not_blank
    CHECK (
      actor_employee_code_snapshot IS NULL
      OR length(btrim(actor_employee_code_snapshot)) > 0
    ),


  -- ==========================================================
  -- JSON payloads must be objects when supplied
  -- ==========================================================

  CONSTRAINT audit_logs_old_data_object
    CHECK (
      old_data IS NULL
      OR jsonb_typeof(old_data) = 'object'
    ),

  CONSTRAINT audit_logs_new_data_object
    CHECK (
      new_data IS NULL
      OR jsonb_typeof(new_data) = 'object'
    ),

  CONSTRAINT audit_logs_metadata_object
    CHECK (
      jsonb_typeof(metadata) = 'object'
    ),


  -- ==========================================================
  -- Financial audit classification
  --
  -- Prevent arbitrary or mismatched level/permission pairs.
  --
  -- Financial audit rows must always be PROJECT scoped because
  -- can_read_financial_class() evaluates authority in a project
  -- context.
  -- ==========================================================

  CONSTRAINT audit_logs_financial_class_check
    CHECK (
      (
        required_financial_level = 0
        AND financial_permission_code IS NULL
      )

      OR

      (
        scope = 'project'
        AND project_id IS NOT NULL

        AND (
          (
            required_financial_level = 2
            AND financial_permission_code =
              'financial.cost_view'
          )

          OR

          (
            required_financial_level = 3
            AND financial_permission_code =
              'financial.contract_view'
          )

          OR

          (
            required_financial_level = 4
            AND financial_permission_code IN (
              'financial.margin_view',
              'financial.collection_view'
            )
          )
        )
      )
    )
);


-- ============================================================
-- 2. Indexes
-- ============================================================

CREATE INDEX audit_logs_occurred_at_idx
ON public.audit_logs (
  occurred_at DESC
);


CREATE INDEX audit_logs_organization_time_idx
ON public.audit_logs (
  organization_id,
  occurred_at DESC
)
WHERE organization_id IS NOT NULL;


CREATE INDEX audit_logs_project_time_idx
ON public.audit_logs (
  project_id,
  occurred_at DESC
)
WHERE project_id IS NOT NULL;


CREATE INDEX audit_logs_actor_time_idx
ON public.audit_logs (
  actor_user_id,
  occurred_at DESC
)
WHERE actor_user_id IS NOT NULL;


CREATE INDEX audit_logs_entity_idx
ON public.audit_logs (
  entity_type,
  entity_key,
  occurred_at DESC
);


CREATE INDEX audit_logs_action_time_idx
ON public.audit_logs (
  action,
  occurred_at DESC
);


-- ============================================================
-- 3. Trusted audit writer
--
-- Direct browser/service-role INSERT is NOT used.
--
-- If auth.uid() exists, it always wins as the actor.
--
-- p_actor_user_id exists only for trusted server/system calls
-- where no end-user JWT exists.
--
-- A browser cannot call this function.
-- ============================================================

CREATE FUNCTION private.write_audit_log(
  p_scope                     text,
  p_entity_type               text,
  p_action                    text,

  p_organization_id           uuid DEFAULT NULL,
  p_project_id                uuid DEFAULT NULL,

  p_entity_key                text DEFAULT NULL,

  p_old_data                  jsonb DEFAULT NULL,
  p_new_data                  jsonb DEFAULT NULL,
  p_metadata                  jsonb DEFAULT '{}'::jsonb,

  p_source                    text DEFAULT 'server',
  p_request_id                text DEFAULT NULL,

  p_actor_user_id             uuid DEFAULT NULL,

  p_required_financial_level  smallint DEFAULT 0,
  p_financial_permission_code text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id                    uuid;
  v_actor_user_id         uuid;
  v_actor_name            text;
  v_actor_employee_code   text;
BEGIN

  -- ----------------------------------------------------------
  -- Authenticated identity wins over an explicitly supplied ID.
  -- This prevents a trusted wrapper called with a user JWT from
  -- accidentally attributing an action to someone else.
  -- ----------------------------------------------------------

  v_actor_user_id :=
    COALESCE(
      (SELECT auth.uid()),
      p_actor_user_id
    );


  -- ----------------------------------------------------------
  -- Snapshot actor identity.
  -- ----------------------------------------------------------

  IF v_actor_user_id IS NOT NULL THEN

    SELECT
      NULLIF(
        btrim(
          COALESCE(pr.first_name, '')
          || ' '
          || COALESCE(pr.last_name, '')
        ),
        ''
      ),

      pr.employee_code

    INTO
      v_actor_name,
      v_actor_employee_code

    FROM public.profiles pr

    WHERE pr.id = v_actor_user_id;

  END IF;


  -- ----------------------------------------------------------
  -- Insert through the trusted writer.
  --
  -- Table constraints remain the final integrity authority.
  -- ----------------------------------------------------------

  INSERT INTO public.audit_logs (
    scope,

    organization_id,
    project_id,

    actor_user_id,
    actor_name_snapshot,
    actor_employee_code_snapshot,

    entity_type,
    entity_key,
    action,

    old_data,
    new_data,
    metadata,

    source,
    request_id,

    required_financial_level,
    financial_permission_code
  )
  VALUES (
    p_scope,

    p_organization_id,
    p_project_id,

    v_actor_user_id,
    v_actor_name,
    v_actor_employee_code,

    p_entity_type,
    p_entity_key,
    p_action,

    p_old_data,
    p_new_data,
    COALESCE(
      p_metadata,
      '{}'::jsonb
    ),

    p_source,
    p_request_id,

    p_required_financial_level,
    p_financial_permission_code
  )
  RETURNING id
  INTO v_id;


  RETURN v_id;

END;
$$;


-- ============================================================
-- 4. Writer privileges
--
-- Only service_role receives direct EXECUTE.
--
-- Future SECURITY DEFINER mutation functions/triggers owned by
-- the database owner can use this writer internally without
-- exposing it to the browser.
-- ============================================================

REVOKE ALL
ON FUNCTION private.write_audit_log(
  text,
  text,
  text,
  uuid,
  uuid,
  text,
  jsonb,
  jsonb,
  jsonb,
  text,
  text,
  uuid,
  smallint,
  text
)
FROM PUBLIC, anon, authenticated;


GRANT EXECUTE
ON FUNCTION private.write_audit_log(
  text,
  text,
  text,
  uuid,
  uuid,
  text,
  jsonb,
  jsonb,
  jsonb,
  text,
  text,
  uuid,
  smallint,
  text
)
TO service_role;


-- ============================================================
-- 5. Append-only mutation guard
--
-- Even the accidental future addition of UPDATE/DELETE
-- privileges cannot silently mutate an audit record.
-- ============================================================

CREATE FUNCTION private.reject_audit_log_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN

  RAISE EXCEPTION
    'Audit logs are immutable and cannot be updated or deleted.'
    USING ERRCODE = '55000';

END;
$$;


REVOKE ALL
ON FUNCTION private.reject_audit_log_mutation()
FROM PUBLIC, anon, authenticated;


CREATE TRIGGER audit_logs_reject_mutation
BEFORE UPDATE OR DELETE
ON public.audit_logs
FOR EACH ROW
EXECUTE FUNCTION private.reject_audit_log_mutation();


-- ============================================================
-- 6. RLS + explicit grants
-- ============================================================

ALTER TABLE public.audit_logs
ENABLE ROW LEVEL SECURITY;


REVOKE ALL
ON TABLE public.audit_logs
FROM PUBLIC;

REVOKE ALL
ON TABLE public.audit_logs
FROM anon;

REVOKE ALL
ON TABLE public.audit_logs
FROM authenticated;

REVOKE ALL
ON TABLE public.audit_logs
FROM service_role;


-- Browser:
-- read only, and still subject to RLS.

GRANT SELECT
ON TABLE public.audit_logs
TO authenticated;


-- Trusted backend:
--
-- SELECT is allowed.
-- INSERT is intentionally NOT granted because all writes must
-- pass through private.write_audit_log().
--
-- UPDATE / DELETE / TRUNCATE remain denied.

GRANT SELECT
ON TABLE public.audit_logs
TO service_role;


-- ============================================================
-- 7. Audit SELECT policy
--
-- PATH A:
--   active Superadmin
--   -> global audit visibility
--
-- PATH B:
--   organization-scoped audit.view
--
-- Financial audit rows additionally require the existing
-- authoritative project financial authorization.
--
-- This prevents audit.view from becoming a financial-data
-- bypass for ordinary business users.
-- ============================================================

CREATE POLICY audit_logs_select_authorized
ON public.audit_logs
FOR SELECT
TO authenticated
USING (

  private.is_superadmin()

  OR

  (
    organization_id IS NOT NULL

    AND private.has_org_permission(
      organization_id,
      'audit.view'
    )

    AND (
      required_financial_level = 0

      OR

      (
        project_id IS NOT NULL

        AND private.can_read_financial_class(
          project_id,
          required_financial_level,
          financial_permission_code
        )
      )
    )
  )
);


-- ============================================================
-- 8. Migration assertions
-- ============================================================

DO $$
BEGIN

  -- ----------------------------------------------------------
  -- Table exists
  -- ----------------------------------------------------------

  IF to_regclass('public.audit_logs') IS NULL THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: audit_logs missing.';
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
      AND c.relname = 'audit_logs'
      AND c.relkind = 'r'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: RLS disabled on audit_logs.';
  END IF;


  -- ----------------------------------------------------------
  -- audit.view permission must already exist
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1
    FROM public.permissions p
    WHERE p.code = 'audit.view'
      AND p.is_active = true
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: audit.view permission missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Project/org integrity FK exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_constraint c

    JOIN pg_class t
      ON t.oid = c.conrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'audit_logs'
      AND c.conname = 'audit_logs_project_org_fkey'
      AND c.contype = 'f'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: project/org FK missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Financial classification constraint exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_constraint c

    JOIN pg_class t
      ON t.oid = c.conrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'audit_logs'
      AND c.conname =
        'audit_logs_financial_class_check'
      AND c.contype = 'c'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: financial-class guard missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Writer exists + SECURITY DEFINER
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'private'
      AND p.proname = 'write_audit_log'
      AND p.prosecdef = true
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: trusted audit writer missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Writer search_path locked
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_proc p

    JOIN pg_namespace n
      ON n.oid = p.pronamespace

    WHERE n.nspname = 'private'
      AND p.proname = 'write_audit_log'
      AND p.proconfig IS NOT NULL
      AND 'search_path=""' = ANY(p.proconfig)
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: audit writer search_path not locked.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated cannot execute writer
  -- ----------------------------------------------------------

  IF has_function_privilege(
    'authenticated',
    'private.write_audit_log(text,text,text,uuid,uuid,text,jsonb,jsonb,jsonb,text,text,uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: authenticated can execute audit writer.';
  END IF;


  -- ----------------------------------------------------------
  -- anon cannot execute writer
  -- ----------------------------------------------------------

  IF has_function_privilege(
    'anon',
    'private.write_audit_log(text,text,text,uuid,uuid,text,jsonb,jsonb,jsonb,text,text,uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: anon can execute audit writer.';
  END IF;


  -- ----------------------------------------------------------
  -- service_role CAN execute writer
  -- ----------------------------------------------------------

  IF NOT has_function_privilege(
    'service_role',
    'private.write_audit_log(text,text,text,uuid,uuid,text,jsonb,jsonb,jsonb,text,text,uuid,smallint,text)',
    'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: service_role cannot execute audit writer.';
  END IF;


  -- ----------------------------------------------------------
  -- PUBLIC pseudo-role cannot execute writer
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
      AND p.proname = 'write_audit_log'

      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: PUBLIC can execute audit writer.';
  END IF;


  -- ----------------------------------------------------------
  -- Append-only guard trigger exists
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_trigger tg

    JOIN pg_class t
      ON t.oid = tg.tgrelid

    JOIN pg_namespace n
      ON n.oid = t.relnamespace

    WHERE n.nspname = 'public'
      AND t.relname = 'audit_logs'
      AND tg.tgname = 'audit_logs_reject_mutation'
      AND tg.tgisinternal = false
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: immutable audit trigger missing.';
  END IF;


  -- ----------------------------------------------------------
  -- Exactly ONE audit RLS policy
  -- ----------------------------------------------------------

  IF (
    SELECT count(*)

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'audit_logs'
  ) <> 1 THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: unexpected audit policy count.';
  END IF;


  -- ----------------------------------------------------------
  -- Policy must be SELECT only
  -- ----------------------------------------------------------

  IF NOT EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'audit_logs'
      AND policyname =
        'audit_logs_select_authorized'
      AND cmd = 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: SELECT policy missing.';
  END IF;


  IF EXISTS (
    SELECT 1

    FROM pg_policies

    WHERE schemaname = 'public'
      AND tablename = 'audit_logs'
      AND cmd <> 'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: audit mutation policy detected.';
  END IF;


  -- ----------------------------------------------------------
  -- authenticated read only
  -- ----------------------------------------------------------

  IF NOT has_table_privilege(
    'authenticated',
    'public.audit_logs',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: authenticated SELECT missing.';
  END IF;


  IF
    has_table_privilege(
      'authenticated',
      'public.audit_logs',
      'INSERT'
    )

    OR has_table_privilege(
      'authenticated',
      'public.audit_logs',
      'UPDATE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.audit_logs',
      'DELETE'
    )

    OR has_table_privilege(
      'authenticated',
      'public.audit_logs',
      'TRUNCATE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: browser audit mutation privilege detected.';
  END IF;


  -- ----------------------------------------------------------
  -- anon no read
  -- ----------------------------------------------------------

  IF has_table_privilege(
    'anon',
    'public.audit_logs',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: anon audit SELECT detected.';
  END IF;


  -- ----------------------------------------------------------
  -- service_role may read but may NOT directly mutate table.
  --
  -- All inserts must pass through write_audit_log().
  -- ----------------------------------------------------------

  IF NOT has_table_privilege(
    'service_role',
    'public.audit_logs',
    'SELECT'
  ) THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: service_role audit SELECT missing.';
  END IF;


  IF
    has_table_privilege(
      'service_role',
      'public.audit_logs',
      'INSERT'
    )

    OR has_table_privilege(
      'service_role',
      'public.audit_logs',
      'UPDATE'
    )

    OR has_table_privilege(
      'service_role',
      'public.audit_logs',
      'DELETE'
    )

    OR has_table_privilege(
      'service_role',
      'public.audit_logs',
      'TRUNCATE'
    )
  THEN
    RAISE EXCEPTION
      'Batch 8 validation failed: service_role direct audit mutation detected.';
  END IF;

END;
$$;
