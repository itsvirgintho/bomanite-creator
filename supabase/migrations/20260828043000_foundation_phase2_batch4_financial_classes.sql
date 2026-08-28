-- ============================================================
-- DFN Control — Foundation Phase 2 — Migration Batch 4
-- Physical financial data separation: F2 / F3 / F4
--
-- This migration:
--   - creates project cost financials (F2 class)
--   - creates project contract financials (F3 class)
--   - creates project executive financials (F4 class)
--   - physically separates financial sensitivity classes
--   - does NOT create financial access policies
--   - does NOT grant browser access
--   - does NOT seed financial data
-- ============================================================


-- ============================================================
-- 1. public.project_cost_financials
--
-- Financial class: F2
-- Required permission later: financial.cost_view
-- ============================================================

CREATE TABLE public.project_cost_financials (
  project_id         uuid          PRIMARY KEY,

  organization_id    uuid          NOT NULL,

  approved_budget    numeric(16,2) NULL,
  forecast_cost      numeric(16,2) NULL,

  currency           text          NOT NULL DEFAULT 'MXN',

  created_at         timestamptz   NOT NULL DEFAULT now(),
  updated_at         timestamptz   NOT NULL DEFAULT now(),

  updated_by         uuid          NULL
                     REFERENCES public.profiles (id)
                     ON DELETE SET NULL,

  CONSTRAINT project_cost_financials_project_org_fkey
    FOREIGN KEY (project_id, organization_id)
    REFERENCES public.projects (id, organization_id)
    ON DELETE RESTRICT,

  CONSTRAINT project_cost_financials_budget_nonnegative
    CHECK (
      approved_budget IS NULL
      OR approved_budget >= 0
    ),

  CONSTRAINT project_cost_financials_forecast_nonnegative
    CHECK (
      forecast_cost IS NULL
      OR forecast_cost >= 0
    ),

  CONSTRAINT project_cost_financials_currency_iso3
    CHECK (
      currency ~ '^[A-Z]{3}$'
    )
);

COMMENT ON TABLE public.project_cost_financials IS
  'F2 financial class. Access requires sufficient financial level '
  'AND the applicable financial.cost_view permission.';

CREATE INDEX project_cost_financials_organization_id_idx
  ON public.project_cost_financials (organization_id);

CREATE TRIGGER project_cost_financials_set_updated_at
  BEFORE UPDATE ON public.project_cost_financials
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.project_cost_financials
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE public.project_cost_financials
  FROM PUBLIC;

REVOKE ALL
  ON TABLE public.project_cost_financials
  FROM anon;

REVOKE ALL
  ON TABLE public.project_cost_financials
  FROM authenticated;

GRANT ALL
  ON TABLE public.project_cost_financials
  TO service_role;


-- ============================================================
-- 2. public.project_contract_financials
--
-- Financial class: F3
-- Required permission later: financial.contract_view
-- ============================================================

CREATE TABLE public.project_contract_financials (
  project_id              uuid          PRIMARY KEY,

  organization_id         uuid          NOT NULL,

  contract_value          numeric(16,2) NULL,

  approved_change_value   numeric(16,2) NOT NULL DEFAULT 0,

  currency                text          NOT NULL DEFAULT 'MXN',

  created_at              timestamptz   NOT NULL DEFAULT now(),
  updated_at              timestamptz   NOT NULL DEFAULT now(),

  updated_by              uuid          NULL
                          REFERENCES public.profiles (id)
                          ON DELETE SET NULL,

  CONSTRAINT project_contract_financials_project_org_fkey
    FOREIGN KEY (project_id, organization_id)
    REFERENCES public.projects (id, organization_id)
    ON DELETE RESTRICT,

  CONSTRAINT project_contract_financials_contract_nonnegative
    CHECK (
      contract_value IS NULL
      OR contract_value >= 0
    ),

  CONSTRAINT project_contract_financials_adjusted_contract_nonnegative
    CHECK (
      contract_value IS NULL
      OR contract_value + approved_change_value >= 0
    ),

  CONSTRAINT project_contract_financials_currency_iso3
    CHECK (
      currency ~ '^[A-Z]{3}$'
    )
);

COMMENT ON COLUMN
  public.project_contract_financials.approved_change_value IS
  'Net approved change value. May be positive or negative.';

COMMENT ON TABLE public.project_contract_financials IS
  'F3 financial class. Access requires sufficient financial level '
  'AND the applicable financial.contract_view permission.';

CREATE INDEX project_contract_financials_organization_id_idx
  ON public.project_contract_financials (organization_id);

CREATE TRIGGER project_contract_financials_set_updated_at
  BEFORE UPDATE ON public.project_contract_financials
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.project_contract_financials
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE public.project_contract_financials
  FROM PUBLIC;

REVOKE ALL
  ON TABLE public.project_contract_financials
  FROM anon;

REVOKE ALL
  ON TABLE public.project_contract_financials
  FROM authenticated;

GRANT ALL
  ON TABLE public.project_contract_financials
  TO service_role;


-- ============================================================
-- 3. public.project_executive_financials
--
-- Financial class: F4
-- Required permission later: financial.margin_view
--
-- target_margin is a RATE:
--   0.1250 = 12.50%
--  -0.0500 = -5.00%
--
-- Absolute margin values are intentionally NOT stored here.
-- ============================================================

CREATE TABLE public.project_executive_financials (
  project_id         uuid         PRIMARY KEY,

  organization_id    uuid         NOT NULL,

  target_margin      numeric(7,4) NULL,

  created_at         timestamptz  NOT NULL DEFAULT now(),
  updated_at         timestamptz  NOT NULL DEFAULT now(),

  updated_by         uuid         NULL
                     REFERENCES public.profiles (id)
                     ON DELETE SET NULL,

  CONSTRAINT project_executive_financials_project_org_fkey
    FOREIGN KEY (project_id, organization_id)
    REFERENCES public.projects (id, organization_id)
    ON DELETE RESTRICT,

  CONSTRAINT project_executive_financials_target_margin_check
    CHECK (
      target_margin IS NULL
      OR target_margin BETWEEN -1 AND 1
    )
);

COMMENT ON COLUMN
  public.project_executive_financials.target_margin IS
  'Target margin rate. Example: 0.1250 = 12.50%.';

COMMENT ON TABLE public.project_executive_financials IS
  'F4 executive financial class. Access requires sufficient financial '
  'level AND the applicable financial.margin_view permission.';

CREATE INDEX project_executive_financials_organization_id_idx
  ON public.project_executive_financials (organization_id);

CREATE TRIGGER project_executive_financials_set_updated_at
  BEFORE UPDATE ON public.project_executive_financials
  FOR EACH ROW
  EXECUTE FUNCTION private.set_updated_at();

ALTER TABLE public.project_executive_financials
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL
  ON TABLE public.project_executive_financials
  FROM PUBLIC;

REVOKE ALL
  ON TABLE public.project_executive_financials
  FROM anon;

REVOKE ALL
  ON TABLE public.project_executive_financials
  FROM authenticated;

GRANT ALL
  ON TABLE public.project_executive_financials
  TO service_role;


-- ============================================================
-- 4. Migration assertions
-- ============================================================

DO $$
BEGIN

  IF (
    SELECT count(*)
    FROM public.project_cost_financials
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 4 validation failed: cost financials must start empty.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.project_contract_financials
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 4 validation failed: contract financials must start empty.';
  END IF;

  IF (
    SELECT count(*)
    FROM public.project_executive_financials
  ) <> 0 THEN
    RAISE EXCEPTION
      'Batch 4 validation failed: executive financials must start empty.';
  END IF;

END;
$$;
