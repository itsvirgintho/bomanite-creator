
-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 2
-- Core RBAC catalog: roles, permissions, role_permissions
--
-- This migration:
--   - creates the 12 business roles
--   - creates the base permission catalog
--   - creates only explicitly approved role mappings
--   - does NOT create Superadmin
--   - does NOT create memberships
--   - does NOT create projects
--   - does NOT create financial levels
--   - does NOT create RLS access policies
--   - does NOT grant browser access
-- ============================================================


-- ============================================================
-- 1. public.roles
-- ============================================================

CREATE TABLE public.roles (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text        NOT NULL UNIQUE,
  name         text        NOT NULL,
  description  text        NULL,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT roles_code_format
    CHECK (code ~ '^[A-Z][A-Z0-9_]{1,63}$'),

  CONSTRAINT roles_name_not_blank
    CHECK (length(btrim(name)) > 0)
);

CREATE TRIGGER roles_set_updated_at
  BEFORE UPDATE ON public.roles
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.roles FROM PUBLIC;
REVOKE ALL ON TABLE public.roles FROM anon;
REVOKE ALL ON TABLE public.roles FROM authenticated;

GRANT ALL ON TABLE public.roles TO service_role;


-- ============================================================
-- 2. public.permissions
-- ============================================================

CREATE TABLE public.permissions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  code         text        NOT NULL UNIQUE,
  name         text        NOT NULL,
  description  text        NULL,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT permissions_code_format
    CHECK (
      code ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
    ),

  CONSTRAINT permissions_name_not_blank
    CHECK (length(btrim(name)) > 0)
);

CREATE TRIGGER permissions_set_updated_at
  BEFORE UPDATE ON public.permissions
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.permissions FROM PUBLIC;
REVOKE ALL ON TABLE public.permissions FROM anon;
REVOKE ALL ON TABLE public.permissions FROM authenticated;

GRANT ALL ON TABLE public.permissions TO service_role;


-- ============================================================
-- 3. public.role_permissions
--
-- IMPORTANT:
-- Scope belongs to the ROLE-PERMISSION relationship.
-- permissions itself intentionally has NO scope column.
-- ============================================================

CREATE TABLE public.role_permissions (
  role_id        uuid        NOT NULL
                 REFERENCES public.roles (id) ON DELETE RESTRICT,

  permission_id  uuid        NOT NULL
                 REFERENCES public.permissions (id) ON DELETE RESTRICT,

  scope          text        NOT NULL,

  created_at     timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (role_id, permission_id, scope),

  CONSTRAINT role_permissions_scope_check
    CHECK (scope IN ('platform', 'organization', 'project'))
);

-- PK already covers role_id as its leading column.
-- Separate index supports reverse permission lookups / FK operations.
CREATE INDEX role_permissions_permission_id_idx
  ON public.role_permissions (permission_id);

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.role_permissions FROM PUBLIC;
REVOKE ALL ON TABLE public.role_permissions FROM anon;
REVOKE ALL ON TABLE public.role_permissions FROM authenticated;

GRANT ALL ON TABLE public.role_permissions TO service_role;


-- ============================================================
-- 4. Seed the 12 BUSINESS roles
--
-- Superadmin intentionally DOES NOT belong in this table.
-- ============================================================

INSERT INTO public.roles (
  code,
  name,
  description
)
VALUES

(
  'DIRECTOR_GENERAL',
  'Director General',
  'Dirección general y visión ejecutiva de la organización.'
),

(
  'DIRECTOR_OPERACIONES',
  'Director de Construcción / Operaciones',
  'Dirección operativa y de construcción.'
),

(
  'GERENTE_PROYECTO',
  'Gerente / Coordinador de Proyecto',
  'Gestión y coordinación integral de proyectos.'
),

(
  'SUPERINTENDENTE_OBRA',
  'Superintendente de Obra',
  'Responsable de supervisión y control operativo de proyectos asignados.'
),

(
  'RESIDENTE_OBRA',
  'Residente de Obra',
  'Responsable operativo de obra dentro de proyectos asignados.'
),

(
  'SUPERVISOR',
  'Supervisor',
  'Supervisión operativa de actividades asignadas.'
),

(
  'MAESTRO_OBRA',
  'Maestro de Obra',
  'Ejecución y coordinación operativa de trabajos en obra.'
),

(
  'CONTROL_COSTOS',
  'Control de Obra / Costos',
  'Control documental, cuantitativo y de costos.'
),

(
  'COMPRAS',
  'Compras',
  'Gestión de compras y abastecimiento.'
),

(
  'ALMACEN',
  'Almacén',
  'Control de almacén, preparación y despacho de materiales.'
),

(
  'CONTABILIDAD',
  'Contabilidad',
  'Gestión contable, facturación, pagos y documentación financiera operativa.'
),

(
  'ADMINISTRACION',
  'Administración',
  'Gestión administrativa de la organización.'
);


-- ============================================================
-- 5. Seed permission catalog
--
-- permissions contains the ACTION/CAPABILITY only.
-- Scope is assigned later through role_permissions.
-- ============================================================

INSERT INTO public.permissions (
  code,
  name
)
VALUES

-- ---------- Administration ----------
('admin.organization.manage',     'Administrar organización'),
('admin.business_unit.manage',    'Administrar unidades de negocio'),
('admin.user.manage',             'Administrar usuarios'),
('admin.membership.manage',       'Administrar membresías'),
('admin.project.manage',          'Administrar proyectos'),
('admin.role.manage',             'Administrar roles'),
('admin.permission.manage',       'Administrar permisos'),

-- ---------- Portfolio ----------
('portfolio.view',                'Ver portafolio'),

-- ---------- Projects ----------
('project.view',                  'Ver proyecto'),
('project.edit',                  'Editar proyecto'),
('project.location.manage',       'Administrar ubicaciones del proyecto'),

-- ---------- Financial ----------
('financial.cost_view',           'Ver costos de proyecto'),
('financial.contract_view',       'Ver información contractual'),
('financial.margin_view',         'Ver márgenes ejecutivos'),
('financial.collection_view',     'Ver cobranza'),

-- ---------- Expenses ----------
('expense.view_all',              'Ver gastos'),
('expense.invoice_manage',        'Administrar facturas de gastos'),
('expense.payment_view',          'Ver pagos de gastos'),

-- ---------- Vendor invoices ----------
('vendor_invoice.view',           'Ver facturas de proveedores'),
('vendor_invoice.create',         'Crear facturas de proveedores'),
('vendor_invoice.validate',       'Validar facturas de proveedores'),

-- ---------- Client invoices ----------
('client_invoice.view',           'Ver facturación a clientes'),
('client_invoice.manage',         'Administrar facturación a clientes'),

-- ---------- Reimbursements ----------
('reimbursement.view',            'Ver reembolsos'),
('reimbursement.update',          'Actualizar reembolsos'),

-- ---------- Material requests ----------
('material_request.create',       'Crear requisiciones de material'),
('material_request.submit',       'Enviar requisiciones de material'),
('material_request.view_own',     'Ver requisiciones propias'),
('material_request.view_project', 'Ver requisiciones del proyecto'),
('material_request.review',       'Revisar requisiciones'),
('material_request.approve',      'Aprobar requisiciones'),
('material_request.reject',       'Rechazar requisiciones'),
('material_request.return',       'Regresar requisiciones para corrección'),

-- ---------- Warehouse ----------
('warehouse.request_view',        'Ver requisiciones en almacén'),
('warehouse.prepare',             'Preparar materiales'),
('warehouse.mark_ready',          'Marcar materiales como listos'),
('warehouse.dispatch',            'Despachar materiales'),

-- ---------- Shipments ----------
('shipment.create',               'Crear envíos'),
('shipment.view',                 'Ver envíos'),
('shipment.update',               'Actualizar envíos'),

-- ---------- Material receipts ----------
('material_receipt.create',       'Crear recepción de materiales'),
('material_receipt.confirm',      'Confirmar recepción de materiales'),

-- ---------- Material incidents ----------
('material_damage.report',        'Reportar material dañado'),
('material_shortage.report',      'Reportar faltantes de material'),

-- ---------- Audit ----------
('audit.view',                    'Ver auditoría');


-- ============================================================
-- 6. Approved initial role-permission mappings
--
-- No admin.* permission is assigned here.
--
-- Roles not explicitly mapped remain with ZERO permissions.
-- ============================================================

WITH mappings (
  role_code,
  permission_code,
  scope
) AS (

  VALUES

  -- ========================================================
  -- Director General — organization
  -- ========================================================

  ('DIRECTOR_GENERAL', 'portfolio.view',              'organization'),
  ('DIRECTOR_GENERAL', 'financial.cost_view',         'organization'),
  ('DIRECTOR_GENERAL', 'financial.contract_view',     'organization'),
  ('DIRECTOR_GENERAL', 'financial.margin_view',       'organization'),
  ('DIRECTOR_GENERAL', 'financial.collection_view',   'organization'),


  -- ========================================================
  -- Superintendente de Obra — project
  -- ========================================================

  ('SUPERINTENDENTE_OBRA', 'project.view',                  'project'),
  ('SUPERINTENDENTE_OBRA', 'financial.cost_view',           'project'),
  ('SUPERINTENDENTE_OBRA', 'financial.contract_view',       'project'),
  ('SUPERINTENDENTE_OBRA', 'material_request.view_project', 'project'),
  ('SUPERINTENDENTE_OBRA', 'material_request.review',       'project'),
  ('SUPERINTENDENTE_OBRA', 'material_request.approve',      'project'),
  ('SUPERINTENDENTE_OBRA', 'material_request.reject',       'project'),
  ('SUPERINTENDENTE_OBRA', 'material_request.return',       'project'),


  -- ========================================================
  -- Residente de Obra — project
  --
  -- financial.cost_view intentionally NOT assigned.
  -- F2 alone must never grant financial access.
  -- ========================================================

  ('RESIDENTE_OBRA', 'project.view',                  'project'),
  ('RESIDENTE_OBRA', 'material_request.create',       'project'),
  ('RESIDENTE_OBRA', 'material_request.submit',       'project'),
  ('RESIDENTE_OBRA', 'material_request.view_own',     'project'),
  ('RESIDENTE_OBRA', 'material_request.view_project', 'project'),
  ('RESIDENTE_OBRA', 'material_receipt.confirm',      'project'),
  ('RESIDENTE_OBRA', 'material_damage.report',        'project'),
  ('RESIDENTE_OBRA', 'material_shortage.report',      'project'),


  -- ========================================================
  -- Maestro de Obra — project
  -- ========================================================

  ('MAESTRO_OBRA', 'project.view',             'project'),
  ('MAESTRO_OBRA', 'material_request.create',  'project'),
  ('MAESTRO_OBRA', 'material_request.submit',  'project'),
  ('MAESTRO_OBRA', 'material_request.view_own','project'),
  ('MAESTRO_OBRA', 'material_receipt.confirm', 'project'),
  ('MAESTRO_OBRA', 'material_damage.report',   'project'),
  ('MAESTRO_OBRA', 'material_shortage.report', 'project'),


  -- ========================================================
  -- Contabilidad — organization
  -- ========================================================

  ('CONTABILIDAD', 'expense.view_all',          'organization'),
  ('CONTABILIDAD', 'expense.invoice_manage',    'organization'),
  ('CONTABILIDAD', 'expense.payment_view',      'organization'),

  ('CONTABILIDAD', 'vendor_invoice.view',       'organization'),
  ('CONTABILIDAD', 'vendor_invoice.create',     'organization'),
  ('CONTABILIDAD', 'vendor_invoice.validate',   'organization'),

  ('CONTABILIDAD', 'client_invoice.view',       'organization'),
  ('CONTABILIDAD', 'client_invoice.manage',     'organization'),

  ('CONTABILIDAD', 'reimbursement.view',        'organization'),
  ('CONTABILIDAD', 'reimbursement.update',      'organization'),


  -- ========================================================
  -- Almacén — organization
  -- ========================================================

  ('ALMACEN', 'warehouse.request_view', 'organization'),
  ('ALMACEN', 'warehouse.prepare',      'organization'),
  ('ALMACEN', 'warehouse.mark_ready',   'organization'),
  ('ALMACEN', 'warehouse.dispatch',     'organization'),

  ('ALMACEN', 'shipment.create',        'organization'),
  ('ALMACEN', 'shipment.view',          'organization'),
  ('ALMACEN', 'shipment.update',        'organization')
)

INSERT INTO public.role_permissions (
  role_id,
  permission_id,
  scope
)

SELECT
  r.id,
  p.id,
  m.scope

FROM mappings m

JOIN public.roles r
  ON r.code = m.role_code

JOIN public.permissions p
  ON p.code = m.permission_code;


-- ============================================================
-- 7. Migration assertions
--
-- These deliberately fail the migration if the seed/mapping
-- catalog is incomplete.
-- ============================================================

DO $$
BEGIN

  IF (SELECT count(*) FROM public.roles) <> 12 THEN
    RAISE EXCEPTION
      'Batch 2 validation failed: expected 12 roles.';
  END IF;

  IF (SELECT count(*) FROM public.permissions) <> 45 THEN
    RAISE EXCEPTION
      'Batch 2 validation failed: expected 45 permissions.';
  END IF;

  IF (SELECT count(*) FROM public.role_permissions) <> 45 THEN
    RAISE EXCEPTION
      'Batch 2 validation failed: expected 45 role-permission mappings.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.role_permissions rp
    JOIN public.permissions p
      ON p.id = rp.permission_id
    WHERE p.code LIKE 'admin.%'
  ) THEN
    RAISE EXCEPTION
      'Batch 2 validation failed: admin permission assigned to business role.';
  END IF;

END;
$$;
