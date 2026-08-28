# DFN Control — Foundation Phase 2

Core backend + real authorization. Replaces the mocked identity/project foundation with Supabase Auth, real membership, RBAC, financial levels, locations, audit and RLS — while preserving the Phase 1 shell, routes and components.

## 1. Architecture

- Identity: Supabase Auth (email/password only, no public sign-up). `profiles` mirrors `auth.users` 1:1.
- Authorization resolved in the database, never in the UI. Frontend reads an "access context" (profile + org membership + project memberships + effective permissions + financial level) exposed through server functions. No views are created in Phase 2; if one is ever added it must be `WITH (security_invoker = true)`.
- Two membership planes: organization-level (Director, Contabilidad, Administración) and project-level (Residente, Supervisor, Maestro, etc.). Project role wins inside a project; org role provides global reach.
- Permissions are a catalog + role mappings + per-project-member overrides. No role-name string checks in code; the client uses permission codes only for UI visibility.
- Helper logic lives in a non-exposed `private` schema (never added to the Data API exposed schemas), `SECURITY DEFINER` only where RLS recursion/bypass is genuinely required, `set search_path = ''`, every relation and function fully qualified. Privileges are least-privilege **per function** — see section 6.
- Sensitive money is **split by sensitivity class into three tables** — `project_cost_financials` (F2), `project_contract_financials` (F3), `project_executive_financials` (F4) — because RLS is row-level, not column-level. Each has its own policy requiring the matching financial level **and** an explicit financial permission.
- **Platform administration is a third, independent plane** (`private.platform_admins`), unrelated to business role and financial level. In Phase 2 all sensitive administrative writes are Superadmin-only. See section 2b.

### 2b. Platform Superadmin layer

`private.platform_admins` (not in `public`, not exposed through the Data API, no grants to `anon`/`authenticated`): id, user_id FK → auth.users (ON DELETE CASCADE), admin_level (CHECK in ('superadmin') for now, extensible), is_active, created_at, created_by. Partial unique on (user_id) WHERE is_active.

Separation rules:
- Superadmin ≠ Director General, ≠ F4, ≠ any org or project role. F4 never implies administration; administration never implies financial visibility.
- A Superadmin who must also see business data receives an explicit organization membership (e.g. Director General + F4). Business reads stay governed by the normal membership/financial policies.
- Helper: `private.is_superadmin()` — **no arguments**; reads `auth.uid()` internally and returns false when it is null. STABLE, SECURITY DEFINER, `search_path = ''`, fully qualified `private.platform_admins`, true only for an active row, boolean return only. `authenticated` receives `USAGE ON SCHEMA private` and `EXECUTE` on this function so policies evaluate under the caller; `anon` and `PUBLIC` are revoked; the schema stays outside the exposed Data API schemas.
- RLS behavior: no BYPASSRLS role is ever used from the browser. **Phase 2 rule: sensitive administrative writes are Superadmin-only** — organizations, business_units, roles, role_permissions, organization_members, project_members, permission overrides, financial levels, the three project financial tables, profile activation and platform/security configuration. Those tables receive write policies `USING/WITH CHECK (private.is_superadmin())` and no generic `user.manage` write path in this phase. Superadmin does **not** get a blanket `is_superadmin() OR ...` SELECT on business tables; the single documented global read exception is audit access. Project operational editing stays governed separately by project permissions.
- Delegated administration is future-ready but not granted now: `admin.organization.manage`, `admin.business_unit.manage`, `admin.user.manage`, `admin.membership.manage`, `admin.project.manage`, `admin.role.manage`, `admin.permission.manage` are seeded in the catalog and mapped to no role. Director General never receives them automatically.
- Auth user management (future, not built in Phase 2): Superadmin browser → authenticated TanStack server function → verify `private.is_superadmin()` server-side → call the Supabase Auth admin API with the service-role key held only in the server runtime → create/invite/deactivate. The secret never reaches frontend code, and the client never calls the admin API directly. For Phase 2, test users are created manually in the Supabase dashboard.
- Navigation readiness only: `src/config/navigation.ts` gains an `admin` group (`/administracion`, `/usuarios`, `/roles`, `/proyectos`, `/permisos`) rendered solely when the access context reports `isSuperadmin`. The routes and module screens are not built in Phase 2.



## 2. Tables and fields

Types first: `financial_level` as constrained `smallint CHECK (between 0 and 4)` — preferred over enum because it is ordinal and comparable (`>= 3`), and adding levels later needs no type migration. Status fields use enums or CHECK-constrained text (project status, location status, member state).

- **organizations**: id, name, legal_name, tax_id?, country, timezone, default_currency, is_active, created_at.
- **business_units**: id, organization_id FK, name, code, is_active, created_at. Unique (organization_id, code).
- **profiles**: id PK/FK → auth.users (CASCADE for the profile row only, while business tables reference `profiles` with RESTRICT/SET NULL so history survives), first_name, last_name, phone?, avatar_path?, job_title?, employee_code?, is_active, created_at, updated_at. Created by an `AFTER INSERT ON auth.users` trigger (SECURITY DEFINER). Deactivation (`is_active = false`) is the normal offboarding path, not deletion. **No unrestricted UPDATE grant to `authenticated`** — RLS is row-level, not column-level, so self-editing goes through a narrow protected function `public.update_own_profile(first_name, last_name, phone, avatar_path)` (SECURITY DEFINER, `search_path = ''`, writes only those columns for `auth.uid()`, EXECUTE granted to `authenticated`). `is_active`, `employee_code` and any future authorization field are writable only through Superadmin-protected paths.
- **roles**: id, organization_id nullable (NULL = system role shared by all orgs), code, name, default_financial_level, is_system_role, is_active. Unique (coalesce(organization_id), code). Seeded with the 12 approved DFN business roles: Director General, Director Construcción/Operaciones, Gerente/Coordinador de Proyecto, Superintendente de Obra, Residente de Obra, Supervisor, Maestro de Obra, Control de Obra/Costos, Compras, Almacén, Contabilidad, Administración. Platform Superadmin is not in this catalog.
- **permissions**: id, code unique, name, category, description. **No `scope` column** — scope is not an intrinsic property of a code.
- **role_permissions**: role_id, permission_id, **scope** text NOT NULL CHECK in ('platform','organization','project'), PK(role_id, permission_id, scope). Scope describes *how a role receives* the permission, so the same code may be organization-scoped for one role and project-scoped for another (e.g. `financial.cost_view`: organization for Director General, project for Residente). Codes are never duplicated to express scope.

- **organization_members**: id, organization_id, user_id, **role_id NULLABLE**, financial_level (default 0), is_active, starts_at, ends_at?, created_at, created_by. Partial unique index on (organization_id, user_id) WHERE is_active. A row with `role_id = NULL` and level F0 means only "this user belongs to DFN" and grants nothing by itself.
- **projects**: id, organization_id, business_unit_id?, project_code, name, client_name, description, project_type, address, latitude, longitude, contract_start_date, contract_end_date, actual_start_date?, actual_end_date?, status, cover_photo_path?, manager_user_id?, created_at, archived_at?. Unique (organization_id, project_code). No money columns.
- **project_cost_financials** (F2 class): project_id PK/FK, approved_budget numeric(16,2), forecast_cost numeric(16,2), currency, updated_at, updated_by.
- **project_contract_financials** (F3 class): project_id PK/FK, contract_value numeric(16,2), approved_change_value numeric(16,2), currency, updated_at, updated_by.
- **project_executive_financials** (F4 class): project_id PK/FK, target_margin numeric(7,4), updated_at, updated_by. `target_margin` is a **rate**, not an amount: 0.1250 = 12.50 % target margin, CHECK between -1 and 1. Absolute margin amounts are derived at query time from contract and cost values, never stored here. No collection/payment rows live in any of these summary tables; future collections derive from dedicated client-invoice/payment entities.
- **project_members**: id, project_id, user_id, role_id, financial_level, starts_at, ends_at?, is_active, assigned_by, created_at. Partial unique (project_id, user_id) WHERE is_active.
- **project_member_permission_overrides**: id, project_member_id, permission_id, allowed bool, valid_from, valid_until?, granted_by, created_at. Unique (project_member_id, permission_id, valid_from). **No scope column** — an override is inherently project-scoped: it only allows/denies project-scoped permissions for that one membership, never organization permissions and never platform Superadmin status.

- **project_locations**: id, project_id, parent_location_id? FK → self (ON DELETE RESTRICT), location_type, code, name, description, sort_order, status, created_at, created_by, archived_at?. Indexes on (project_id, parent_location_id) and (project_id, sort_order). CHECK (id <> parent_location_id) blocks self-parenting; deeper cycles are prevented by a BEFORE INSERT/UPDATE trigger that walks ancestors recursively and raises on revisit, plus a CHECK that parent belongs to the same project.
- **audit_logs**: id, organization_id, project_id?, actor_user_id, actor_name_snapshot, action, entity_type, entity_id, old_values jsonb, new_values jsonb, ip_address?, user_agent?, created_at. Append-only: no UPDATE/DELETE grants or policies for `authenticated`; writes happen through SECURITY DEFINER triggers/functions.

Delete behavior: RESTRICT for roles, projects, memberships referenced by history; SET NULL for optional actor references; CASCADE only for overrides under their member row and profile under auth user.

## 3. Relationship diagram

```text
auth.users 1─1 profiles
organizations 1─* business_units
organizations 1─* organization_members *─0..1 roles   (role_id NULLABLE)
organizations 1─* projects *─0..1 business_units
projects 1─0..1 project_cost_financials        (F2 + financial.cost_view)
projects 1─0..1 project_contract_financials    (F3 + financial.contract_view)
projects 1─0..1 project_executive_financials   (F4 + financial.margin_view)


projects 1─* project_members *─1 roles
project_members 1─* project_member_permission_overrides *─1 permissions
projects 1─* project_locations ─* (self, recursive)
roles *─* permissions (role_permissions, PK role_id+permission_id+scope)
organizations 1─* audit_logs *─0..1 projects
```

## 4. Access resolution algorithm (deterministic, scope-aware)

Scope lives on `role_permissions`, not on `permissions`. A mapping is only honored on the plane matching `role_permissions.scope`. **An organization role holding a project-scoped mapping never converts it into organization-wide access, and a project-scoped mapping never leaks to the organization plane.**

1. `uid = auth.uid()`; require `profiles.is_active = true`. Otherwise nothing is granted.
2. Org plane: the active `organization_members` row (starts_at <= now, ends_at null or > now, is_active). If `role_id IS NULL`, the user is merely a DFN member: **zero organization permissions, organization financial level treated as F0**, no project reach. If `role_id` is set, org permissions = that role's mappings **with `role_permissions.scope = 'organization'`** only.
3. Project plane, per project P: the active `project_members` row for P. Project permissions = that role's mappings **with `role_permissions.scope = 'project'`**, then apply overrides for that membership valid at now(): `allowed = false` wins over any grant; `allowed = true` adds. Overrides affect the project set only.

4. Project visibility is two distinct, non-interchangeable paths:
   - **A. Direct project access** — an active `project_members` row for P (with the relevant project permission for the action).
   - **B. Organization portfolio access** — an explicit organization-scoped permission such as `portfolio.view` held by an org role (Director General, authorized Contabilidad, authorized management). This is deliberately assigned, never implied by a job title.
   Residente, Maestro, Supervisor and project-scoped Superintendente therefore see only their assigned projects; an organization membership alone never creates project access.
5. Effective financial level for project P:
   - base = project membership `financial_level` when an active membership exists, else 0;
   - the organization membership level supplements it **only when the org role holds the organization-scoped authority covering that data class** (i.e. path B applies to P and the org role holds the required `financial.*` permission at organization scope);
   - otherwise `effective = project level`. Never a blanket `max(org, project)`; a passive membership (role NULL, F0) contributes nothing.
6. Financial reads are per sensitivity table, each with its own policy — no single policy spans classes. Each requires visibility, level and the financial permission **through the matching access path**:
   - Direct project path: active project membership + the code mapped at `scope = 'project'` for the project role.
   - Organization/global path: active org membership with non-null role + the code mapped at `scope = 'organization'`.
   - `project_cost_financials`: visibility **and** effective level >= 2 **and** `financial.cost_view` on the same path.
   - `project_contract_financials`: visibility **and** effective level >= 3 **and** `financial.contract_view` on the same path.
   - `project_executive_financials`: visibility **and** effective level >= 4 **and** `financial.margin_view` on the same path.
   The two paths are evaluated separately and never merged ambiguously. Consequences: Cecy (Contabilidad F2 + organization-scoped accounting codes) reads neither contract nor executive rows; Almacén (F0/F1) reads none of the three; Diego Residente (F2) reads cost rows only if his project role has `financial.cost_view` at project scope; Miguel (F3) reads cost/contract only with the explicit project-scoped permissions on assigned projects; Pablo (F4) reads all three through organization-scoped mappings plus level; Superadmin platform status alone grants nothing on these tables.

7. Organization scoping is explicit: the organization_id always comes from the protected resource or from the caller's membership row passed into the helper. There is no ambiguous `private.current_org()`; if it is ever reintroduced it must raise on more than one active organization membership rather than silently picking the first.


## 5. GRANTs and RLS per table

GRANT decides whether a role may attempt an operation; RLS decides which rows. Both are specified explicitly; Supabase default privileges are not relied upon. Every table starts with `REVOKE ALL ... FROM PUBLIC, anon;` — `anon` receives no privilege on any DFN business table. `service_role` receives `ALL` on public tables for server-side maintenance. RLS is enabled on every public table.

**Phase 2 rule: `authenticated` receives SELECT only, on every table.** No generic client INSERT/UPDATE/DELETE exists anywhere in this phase, including `projects` and `project_locations` — no project-administration or location-editor UI is being built. Initial configuration is done with reviewed bootstrap/admin SQL. Being Superadmin does **not** give the browser unrestricted write grants; later administration will run through narrowly scoped trusted server functions that verify Superadmin server-side.

| Table | GRANT to `authenticated` | SELECT policy | Client writes in Phase 2 |
|---|---|---|---|
| organizations | SELECT | active org member | none |
| business_units | SELECT | active org member | none |
| profiles | SELECT | self, or same-org member | none — self edits only via `public.update_own_profile` |
| organization_members | SELECT | own rows only (where permitted) | none |
| roles | SELECT | active org member (read-only catalog) | none |
| permissions | SELECT | active org member | none |
| role_permissions | SELECT | active org member | none |
| projects | SELECT | `private.can_access_project(id)` | none (`project.edit` is seeded for future protected APIs, not a row UPDATE grant) |
| project_cost_financials | SELECT | visibility + level >= 2 + `financial.cost_view` on the matching path | none |
| project_contract_financials | SELECT | visibility + level >= 3 + `financial.contract_view` on the matching path | none |
| project_executive_financials | SELECT | visibility + level >= 4 + `financial.margin_view` on the matching path | none |
| project_members | SELECT | own rows, or members of projects the caller can access | none |
| project_member_permission_overrides | SELECT | via parent member visibility | none |
| project_locations | SELECT | `private.can_access_project(project_id)` | none (future protected mutation path) |
| audit_logs | SELECT | `audit.view` scoped to org/project, or Superadmin | none; written only by definer triggers/functions |
| private.platform_admins | none | none from the client (schema not exposed) | none from the client; set by the one-time bootstrap script |


Security-bearing rows (`organization_members`, `project_members`, overrides, `roles`, `role_permissions`, and the three financial tables) therefore have **no client mutation grant at all** in Phase 2 — a normal user cannot even attempt the write, so correctness does not depend on subtle RLS expressions. Each financial table gets its own single-class SELECT policy; no policy covers more than one sensitivity class.

Dependency graph (avoids recursion): policies on business tables call `private.*` SECURITY DEFINER helpers, which read membership tables with RLS bypassed. Membership tables' own policies use only `auth.uid()` comparisons or `private.is_superadmin()` — never a policy on the same table it queries. `private.platform_admins` has no client-reachable policy, so `is_superadmin` cannot recurse.

## 6. Helper functions (schema `private`) — least privilege per function

The `private` schema is never added to the Supabase Data API exposed schemas, so nothing here is published as an RPC endpoint. Two distinct classes:

**A. Internal policy helpers** — referenced inside RLS policies, so the *caller* must be able to execute them. `GRANT USAGE ON SCHEMA private TO authenticated;` plus `GRANT EXECUTE` on each named function individually — never `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA private`, and no default privileges. All are STABLE, SECURITY DEFINER (required to read membership tables without recursion), `set search_path = ''`, fully qualified, boolean/scalar return only, and revoked from `PUBLIC` and `anon`:

`private.is_superadmin()` — **no argument**; resolves `auth.uid()` internally, returns false when it is null, boolean only. There is no Phase 2 need for a caller to ask whether an arbitrary UUID is Superadmin. Also: `private.is_organization_member(uuid)`, `private.has_org_permission(text)` (honors only mappings with `role_permissions.scope = 'organization'` for the caller's active org role, and only when that role is non-null), `private.is_project_member(uuid)`, `private.can_access_project(uuid)` (direct membership OR explicit organization-scoped portfolio permission), `private.has_project_permission(uuid, text)` (honors only mappings with `scope = 'project'` for the active project membership, then applies valid overrides), `private.effective_financial_level(uuid)` (implements §4.5; no blanket `max(org, project)`), and `private.can_read_financial_class(uuid, smallint, text)`, which checks visibility, level and the financial code **on the same access path** for the three financial-table policies.

**B. Privileged mutation functions** — administrative or write-capable definer functions. `REVOKE ALL FROM PUBLIC, anon, authenticated`; EXECUTE is granted only when the function *is* the intentional protected API for that operation, and the function verifies the caller itself (`private.is_superadmin()` or the required permission) before mutating. The audit-write functions stay unreachable from the client and are invoked only by triggers.

`public.update_own_profile(_first_name, _last_name, _phone, _avatar_path)` is the one deliberately client-callable protected mutation in Phase 2. Contract: **no target user_id argument ever** (the row is always `auth.uid()`); requires `auth.uid() IS NOT NULL`; requires the caller's `public.profiles.is_active = true`, otherwise it raises; updates only those four self-service columns; never touches `is_active`, `employee_code` or any authorization field; SECURITY DEFINER with `search_path = ''` and fully qualified relations/functions; `REVOKE EXECUTE FROM PUBLIC, anon`; `GRANT EXECUTE TO authenticated` only.

No views are created in Phase 2. Any future view exposed to `authenticated` must be `WITH (security_invoker = true)` so caller RLS applies.



## 7. Migration order (small, reviewable)

1. `private` schema + shared types/CHECK domains + `updated_at` trigger fn.
2. organizations, business_units.
3. profiles + auth.users trigger.
4. roles, permissions, role_permissions.
5. organization_members.
6. projects, then `project_cost_financials`, `project_contract_financials`, `project_executive_financials` (each its own small migration so policies stay reviewable per sensitivity class).
7. project_members, overrides.
8. project_locations (+ cycle trigger).
9. audit_logs + audit write function/triggers.
10. `private.platform_admins`.
11. private helper functions (including `is_superadmin`) + `public.update_own_profile`.
12. Explicit REVOKE/GRANT statements (schema USAGE, per-function EXECUTE, per-table privileges) and RLS policies for all of the above, including the Superadmin-only administrative write policies.
13. Seed reference data (12 roles, permission catalog, role mappings) — no personal identifiers.

Each step is a separate migration presented for approval. The identity bootstrap is NOT a migration: it is a separate one-time reviewed script (section 9).

## 8. Permission catalog (including Materials/Warehouse readiness)

The catalog is seeded in full in Phase 2 even though several codes have no screen yet. Categories: `project`, `admin`, `audit`, `financial`, `expense`, `vendor_invoice`, `client_invoice`, `reimbursement`, `material_request`, `warehouse`, `shipment`, `material_receipt`, `material_issue`.

Every permission carries an explicit `scope` (`platform` | `organization` | `project`) that decides on which plane a role mapping is honored:

| Code group | Scope |
|---|---|
| `portfolio.view` | organization |
| `project.view`, `project.edit`, `project.location.manage` | project |
| `financial.cost_view`, `financial.contract_view` | project |
| `financial.margin_view`, `financial.collection_view` | project (may additionally be mapped at organization scope only by explicit executive role assignment) |
| `audit.view` | organization (project-scoped audit reads use a separate `audit.view_project` code) |
| `admin.*` | platform |
| accounting codes (`expense.*`, `vendor_invoice.*`, `client_invoice.*`, `reimbursement.*`) | organization where cross-project by nature, project where the record is project-bound |
| `material_request.*`, `material_receipt.*`, `material_damage.report`, `material_shortage.report` | project |
| `warehouse.*`, `shipment.*` | organization (the warehouse serves all projects) |

A project-scoped code mapped to an organization role grants nothing organization-wide; it is only honored inside projects the user actually reaches through §4.4.

Administration codes are seeded but mapped to **no role** in Phase 2 (Superadmin-only writes cover these operations for now): `admin.organization.manage`, `admin.business_unit.manage`, `admin.user.manage`, `admin.membership.manage`, `admin.project.manage`, `admin.role.manage`, `admin.permission.manage`. The generic `user.manage` key is retired as an authorization key. Financial codes are explicit per class: `financial.cost_view` (F2 → `project_cost_financials`), `financial.contract_view` (F3 → `project_contract_financials`), `financial.margin_view` (F4 → `project_executive_financials`), `financial.collection_view` (F4, reserved for future collection entities).


Accounting/administrative codes (granular, so Contabilidad does not need a high financial level):
`expense.view_all`, `expense.invoice_manage`, `expense.payment_view`, `vendor_invoice.view`, `vendor_invoice.create`, `vendor_invoice.validate`, `client_invoice.view`, `client_invoice.manage`, `reimbursement.view`, `reimbursement.update`.

Materials/Warehouse codes (future-ready, unused by Phase 2 screens):
`material_request.create`, `material_request.submit`, `material_request.view_own`, `material_request.view_project`, `material_request.review`, `material_request.approve`, `material_request.reject`, `material_request.return`, `warehouse.request_view`, `warehouse.prepare`, `warehouse.mark_ready`, `warehouse.dispatch`, `shipment.create`, `shipment.view`, `shipment.update`, `material_receipt.create`, `material_receipt.confirm`, `material_damage.report`, `material_shortage.report`.

Default role→permission mappings seeded now:
- Maestro de Obra: `material_request.create`, `.submit`, `.view_own`, `material_receipt.confirm`, `material_damage.report`, `material_shortage.report`.
- Residente de Obra: the Maestro requester/receiver set plus `material_request.view_project`.
- Superintendente de Obra: `material_request.view_project`, `.review`, `.approve`, `.reject`, `.return`.
- Director General / authorized management: approval permissions, applied per organization/project policy rather than assumed.
- Almacén: `warehouse.request_view`, `warehouse.prepare`, `warehouse.mark_ready`, `warehouse.dispatch`, `shipment.create`, `shipment.view`, `shipment.update`.
- Contabilidad: the accounting/administrative codes above; no warehouse or shipment permissions.

Financial level stays independent of these codes: a permission grants an action, the level gates money visibility.

## 8b. Future Materials/Warehouse domain (NOT built in Phase 2)

Recorded so the RBAC seeded now stays correct; no tables are created in this phase.

Flow: Maestro/Residente draft → submit → approval by Superintendente and/or Director per configurable project policy (superintendent only, director only, either authorized approver, or superintendent then director) → warehouse queue → stock check → preparing → partially prepared or ready → shipment created → dispatched → in transit → delivered → site confirmation → received OK or received with damage/shortage → closed only when outstanding problems are resolved.

Modeling rules to honor later: a request carries project, location, optional activity/concept, requester, requested date, required-by date, urgency, notes and attachments; each request item tracks requested, approved, prepared, dispatched, received, damaged, missing and backordered quantities independently — never a single generic quantity/status. A request may have multiple shipments, so tracking/guide numbers live on `material_shipments` (carrier, internal driver, vehicle, tracking number, dispatch timestamp, ETA, actual delivery, status, evidence, notes), not on the request. Receipts are recorded per item with dispatched/received/damaged/missing quantities, condition, comments and photographic evidence. Status/event history is preserved in dedicated history tables so a timeline (Requested → Approved → Preparing → Ready → Dispatched → In transit → Delivered → Received) with user and timestamp can be rendered. Notification events for requester, approver and warehouse are anticipated by the permission model but no notification logic is built.

Anticipated future entities: `material_requests`, `material_request_items`, `material_request_approvals`, `material_request_status_history`, `material_shipments`, `material_shipment_items`, `shipment_status_history`, `material_receipts`, `material_receipt_items`, `material_damage_reports` (+ attachments). None created in Phase 2.

Warehouse users must never automatically see contract value, unit prices sold to the client, project margin, collections or executive financial data — hence F0/F1 and no `financial.*` permissions. Production warehouse access should use individual named users with the Almacén role so preparation and dispatch actions remain attributable; a generic warehouse identity is acceptable only in development.

## 9. Seed / reference data

Seed only: the DFN Desarrollo e Infraestructura organization, the two business units, the approved roles (including Superintendente de Obra and Almacén as confirmed real roles) with default financial levels, the full permission catalog above, and role→permission mappings. No fake projects or financials. The org UUID is never hard-coded in the frontend; the client resolves it from the user's `organization_members` row.

Seed files contain **no personal emails, names, passwords or other personal identifiers**. Identity bootstrap is a separate, reviewed, one-time script — never a reusable migration:

1. Create the Auth users manually in the Supabase dashboard.
2. Read each `auth.users` UUID from the dashboard.
3. Run the one-time bootstrap script that inserts memberships, financial levels and the first `private.platform_admins` row **by explicit UUID**, not by email matching.
4. The script is not committed as a schema migration and is not re-runnable as part of the reference seed.

Real test identity matrix (all non-Superadmin unless stated); identities are named here for planning only and are attached in the database by UUID:


| Identity | Organization membership (role / level) | Project membership (role / level) | Platform Superadmin |
|---|---|---|---|
| Diego (admin account) | NULL role / F0 (Director General + F4 may be added explicitly for business testing) | none by default | Yes |
| Pablo Avilés | Director General / F4 (+ `portfolio.view`) | none required | No |
| Miguel Ángel Tobón | NULL role / F0 | Superintendente de Obra / F3 on assigned projects | No |
| Diego (second account) | NULL role / F0 | Residente de Obra / F2 on Maraluna only | No |
| Ricardo | NULL role / F0 | Maestro de Obra / F1 on assigned project | No |
| Cecy | Contabilidad / F2 (organization-scoped accounting codes) | none required | No |
| Warehouse test user | Almacén / F0–F1 (organization-scoped warehouse codes) | none required | No |


The two mandatory owner accounts remain distinct real Supabase Auth users and are never simulated with DemoRoleSwitcher once real auth is on: Account A = Diego Superadmin; Account B = Diego Residente scoped to the selected test project only.

Cecy is explicitly F2: Contabilidad does not automatically imply F4. Contract, estimate and collection visibility is granted later only by explicit level/permission changes.



## 10. Auth flow and mock-to-real migration

Auth: `/auth` becomes real `signInWithPassword`; real `signOut` (cancel queries, clear cache, replace-navigate to `/auth`); password reset via Supabase's built-in reset email (free tier, no paid service). No sign-up UI.

Staged migration, demo system stays until each stage is green:
1. Add a real `AuthContext` (Supabase session) alongside the mock session; app still uses mock.
2. Add server functions returning access context and authorized project list.
3. Switch `SessionContext` internals to real data behind the same interface, so `AppShell`, `SidebarNav`, `MobileBottomNav`, `ProjectSwitcher` and role homes stay unchanged.
4. Move protected routes under the managed `_authenticated` gate; `/auth` and `/` stay public.
5. `ProjectSwitcher` and `/proyecto/$projectId` load only authorized projects; an unauthorized/unknown id renders "Proyecto no disponible o sin acceso" (no content leak, no distinction fishing).
6. Once verified, remove `DemoRoleSwitcher`, demo users/projects from `src/mocks`, and the mock branches — keeping only clearly labeled demo data for still-mocked operational widgets, or removing the "Datos de demostración" notice where data is now real.

## 11. Navigation readiness (no screens built)

`src/config/navigation.ts` gains permission-driven, not role-name-driven, entries that stay hidden until the real access context reports the codes: project materials `/proyecto/$projectId/materiales` (shown with `material_request.view_own` or `.view_project`) and global warehouse `/almacen` (shown with `warehouse.request_view`), plus the Superadmin `administracion` group. Route files and module screens are NOT created in Phase 2; the config entries stay inert until the modules exist.

Role visibility additions for the new real roles: Superintendente de Obra sees project operational destinations plus approval-oriented entries later; Almacén sees only global warehouse plus profile — no portfolio, no estimates, no financial destinations.

## 12. Security test matrix

Business access: Pablo (Director, org role + `portfolio.view`) reaches all org projects and reads the financial classes his explicit permissions cover; Residente reads assigned project only, 0 rows for any unrelated project; Maestro assigned project only and 0 rows from all three financial tables; Anonymous 0 rows everywhere. Plus expired membership → no access; inactive membership → no access; override deny removes a role-granted project permission; override allow grants one; unauthorized project URL renders the unavailable state; direct PostgREST query with a known UUID returns empty.

Scope and membership-plane tests:
- Diego Residente: organization membership exists with `role_id = NULL`; only the Maraluna project membership grants access; any other DFN project returns zero rows; adding/keeping an organization membership alone never creates project access; at F2 he reads `project_cost_financials` for Maraluna only if his project role explicitly holds `financial.cost_view`, and reads 0 rows from contract and executive tables.
- Miguel: Superintendente permissions apply only inside explicitly assigned projects; unassigned projects return zero rows unless a separately configured organization-level role is granted.
- Pablo: the organization Director role with `portfolio.view` grants the intended portfolio/global project access.
- Cecy: organization-scoped Contabilidad permissions support cross-project accounting flows; F2 accounting access exposes neither `project_contract_financials` nor `project_executive_financials`.
- Almacén: organization-scoped warehouse permission may expose the future cross-project warehouse queue; all three financial tables return 0 rows.
- A project-scoped permission mapped onto an organization role does not grant organization-wide project access.

Financial-table isolation tests:
- An F2 user with `financial.cost_view` reads allowed `project_cost_financials` rows and gets 0 rows / permission denied from contract and executive tables.
- An F3 user does not automatically read the executive table.
- An F4 user without the explicit `financial.margin_view` permission is denied the executive table.
- Superadmin platform status alone returns 0 rows from all three financial tables.

Role tests:
- Cecy (Contabilidad, F2): holds the accounting permission codes; holds no warehouse or shipment permission.
- Warehouse user (Almacén, F0/F1): holds only warehouse/shipment codes; cannot read contract value, unit prices, margin or collections; cannot approve material requests.
- Superintendente (Miguel Ángel Tobón, F3): holds review/approve/reject/return codes; no warehouse codes; no platform administration.
- Maestro (Ricardo, F1): requester/receiver codes only; no approval, warehouse or financial codes.


Platform administration (run with the two real accounts):
- Account A (Superadmin): can perform permitted administrative writes through the approved protected paths; sees the administration navigation; reads business/financial data only through its separately assigned Director General + F4 membership, except the documented audit-read policy.
- Director non-Superadmin: F4 grants no administration; cannot change roles, permissions, memberships or financial levels.
- Account B (Residente): `private.platform_admins` is unreadable (function/table not in the API); admin navigation hidden and admin URLs render unauthorized; cannot assign roles, modify memberships, change financial levels or view unrelated projects; direct Supabase API attempts blocked by grants/RLS.
- Privilege escalation (all must fail): insert self into platform_admins; modify own `organization_members` row; change own role_id; raise own financial_level; change own `ends_at`/`is_active`; insert a project_members row for self; insert a permission override for self; grant self any material_request approval or warehouse permission.

Grants and helper-privilege tests:
- Signed-in user queries a policy-protected table successfully — proving `authenticated` really can execute the `private` policy helpers (USAGE + per-function EXECUTE granted).
- The `private` helpers are NOT callable as Data API RPC (`/rest/v1/rpc/is_superadmin` fails; the schema is not exposed) and `anon` cannot execute them.
- Privileged mutation functions are not executable by `authenticated` except `public.update_own_profile`.
- Resident updates `phone` via `update_own_profile` successfully, and cannot change `is_active` or `employee_code` by any path (no UPDATE grant on `public.profiles`).
- Resident's direct INSERT/UPDATE on `organization_members`, `project_members`, overrides, `roles`, `role_permissions` fails at the GRANT level, not just RLS.
- Director F4 (non-Superadmin) cannot administer RBAC or memberships.
- Cecy's accounting permissions return 0 rows from the contract and executive financial tables at F2; Almacén returns 0 rows from all three.
- Superadmin platform status alone returns 0 rows from all three financial tables without a separately assigned membership and level.

- If any view exists, it is `security_invoker = true` and returns caller-scoped rows.



## 13. Risks and edge cases

RLS recursion on membership tables (mitigated by the definer helpers); policy performance on hot paths (indexes on membership `(user_id, project_id) WHERE is_active`); trigger-created profiles failing silently for dashboard users; users with org role but no project membership; clock/timezone handling for starts_at/ends_at; accidental `anon` grants; auth user deletion orphaning history (use deactivation); seeded-but-unused permission codes drifting from the future Materials schema (mitigated by section 8b being the contract for that module); shared warehouse logins breaking attributability in production.

## 14. Cost

Supabase Free, current Lovable plan, GitHub Free only. No new paid services and no new frontend dependencies.

## 15. Acceptance checklist

- The 15 public core tables (the three split financial tables replace `project_financials`) plus `private.platform_admins` exist with PKs, FKs, uniques, checks, indexes and restrictive deletes.
- Every public table has explicit REVOKE/GRANT statements for `anon`, `authenticated` and `service_role`, plus RLS enabled and policies; nothing relies on Supabase default privileges. `anon` holds no privilege on any DFN business table.
- Security-bearing tables (`organization_members`, `project_members`, overrides, `roles`, `role_permissions`, and the three financial tables) have no client mutation grant at all.
- `private` is not in the Data API exposed schemas; `authenticated` has `USAGE ON SCHEMA private` and per-function `EXECUTE` only on the named policy helpers, and RLS queries actually succeed for signed-in users.
- Privileged mutation functions are revoked from `authenticated`; the only client-callable protected mutation is `public.update_own_profile`, restricted to first_name, last_name, phone and avatar_path for `auth.uid()`.
- All `private` functions are `search_path = ''`, fully qualified, and SECURITY DEFINER only where RLS recursion/bypass genuinely requires it.
- 12 business roles are seeded; every reference to 11 has been corrected; Superadmin is not a business role.
- Phase 2 sensitive administrative writes are Superadmin-only; `admin.*` delegated codes are seeded but mapped to no role; Director General F4 grants no administration.
- Financial data is split into `project_cost_financials` (F2 + `financial.cost_view`), `project_contract_financials` (F3 + `financial.contract_view`) and `project_executive_financials` (F4 + `financial.margin_view`), each with its own single-class SELECT policy; no policy spans classes and no column-level privileges are relied on. `target_margin` is documented as a rate (0.1250 = 12.50 %).
- `organization_members.role_id` is nullable; a membership with NULL role and F0 grants nothing, and project-scoped employees gain no organization-wide reach.
- `permissions.scope` exists with CHECK ('platform','organization','project'); mappings are honored only on the matching plane, and project visibility distinguishes direct project membership from explicit organization portfolio permission.
- Effective financial level follows the documented deterministic rule; no blanket `max(org, project)`.
- `public.update_own_profile` takes no target user_id, requires an active caller profile, writes only the four self-service columns, and is executable only by `authenticated`.

- Superadmin has no blanket `is_superadmin() OR ...` SELECT on business tables; audit read is the only documented global exception.
- No views are created; any future view is `security_invoker = true`.
- No ambiguous `private.current_org()` exists; organization_id is always explicit.
- No BYPASSRLS database role is used from the browser; no service-role credential appears in frontend code.
- Profile auto-created for dashboard-created auth users.
- Real login, logout and password reset work; no sign-up UI exists.
- Role/permission/financial-level resolution comes from the database, not from role-name checks in the client.
- The full permission catalog is seeded, including accounting, admin and Materials/Warehouse codes, with the stated role defaults.
- Superintendente de Obra and Almacén exist as real seeded roles; Almacén defaults to F0/F1 with no `financial.*` permissions; Contabilidad is F2.
- Seed/migration files contain no personal emails, names or passwords; identities are attached by UUID through a separate one-time bootstrap script.
- The seven real test identities are configured; two distinct real Supabase accounts (Superadmin and Residente) pass their matrix rows; all privilege-escalation attempts fail.
- Every item of the security test matrix passes, including the grant/helper-privilege tests.
- Navigation config is permission-driven and ready for `/administracion`, `/proyecto/$projectId/materiales` and `/almacen`, but none of those screens or routes are built.
- Phase 1 shell, routes and components still render for all roles with real data.
- Demo session/role switcher removed only after real auth is confirmed.
- No operational or Materials/Warehouse tables created; typecheck and build clean.



