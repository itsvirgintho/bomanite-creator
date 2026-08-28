# DFN Control — Foundation Phase 2

Core backend + real authorization. Replaces the mocked identity/project foundation with Supabase Auth, real membership, RBAC, financial levels, locations, audit and RLS — while preserving the Phase 1 shell, routes and components.

## 1. Architecture

- Identity: Supabase Auth (email/password only, no public sign-up). `profiles` mirrors `auth.users` 1:1.
- Authorization resolved in the database, never in the UI. Frontend reads an "access context" (profile + org membership + project memberships + effective permissions + financial level) exposed through server functions. No views are created in Phase 2; if one is ever added it must be `WITH (security_invoker = true)`.
- Two membership planes: organization-level (Director, Contabilidad, Administración) and project-level (Residente, Supervisor, Maestro, etc.). Project role wins inside a project; org role provides global reach.
- Permissions are a catalog + role mappings + per-project-member overrides. No role-name string checks in code; the client uses permission codes only for UI visibility.
- Helper logic lives in a non-exposed `private` schema (never added to the Data API exposed schemas), `SECURITY DEFINER` only where RLS recursion/bypass is genuinely required, `set search_path = ''`, every relation and function fully qualified. Privileges are least-privilege **per function** — see section 6.
- Sensitive money lives only in `project_financials`, gated by financial level **and** an explicit financial permission.
- **Platform administration is a third, independent plane** (`private.platform_admins`), unrelated to business role and financial level. In Phase 2 all sensitive administrative writes are Superadmin-only. See section 2b.

### 2b. Platform Superadmin layer

`private.platform_admins` (not in `public`, not exposed through the Data API, no grants to `anon`/`authenticated`): id, user_id FK → auth.users (ON DELETE CASCADE), admin_level (CHECK in ('superadmin') for now, extensible), is_active, created_at, created_by. Partial unique on (user_id) WHERE is_active.

Separation rules:
- Superadmin ≠ Director General, ≠ F4, ≠ any org or project role. F4 never implies administration; administration never implies financial visibility.
- A Superadmin who must also see business data receives an explicit organization membership (e.g. Director General + F4). Business reads stay governed by the normal membership/financial policies.
- Helper: `private.is_superadmin(_user_id uuid default auth.uid())` — STABLE, SECURITY DEFINER, `search_path = ''`, fully qualified `private.platform_admins`, returns true only for an active row. It is an **internal policy helper**: `authenticated` receives `USAGE ON SCHEMA private` and `EXECUTE` on this specific function so policies evaluate under the caller; `anon` and `PUBLIC` are revoked. It returns a boolean only and cannot read or mutate data.
- RLS behavior: no BYPASSRLS role is ever used from the browser. **Phase 2 rule: sensitive administrative writes are Superadmin-only** — organizations, business_units, roles, role_permissions, organization_members, project_members, permission overrides, financial levels, `project_financials` configuration, profile activation and platform/security configuration. Those tables receive write policies `USING/WITH CHECK (private.is_superadmin())` and no generic `user.manage` write path in this phase. Superadmin does **not** get a blanket `is_superadmin() OR ...` SELECT on business tables; the single documented global read exception is audit access. Project operational editing stays governed separately by project permissions.
- Delegated administration is future-ready but not granted now: `admin.organization.manage`, `admin.business_unit.manage`, `admin.user.manage`, `admin.membership.manage`, `admin.project.manage`, `admin.role.manage`, `admin.permission.manage` are seeded in the catalog and mapped to no role. Director General never receives them automatically.
- Auth user management (future, not built in Phase 2): Superadmin browser → authenticated TanStack server function → verify `private.is_superadmin()` server-side → call the Supabase Auth admin API with the service-role key held only in the server runtime → create/invite/deactivate. The secret never reaches frontend code, and the client never calls the admin API directly. For Phase 2, test users are created manually in the Supabase dashboard.
- Navigation readiness only: `src/config/navigation.ts` gains an `admin` group (`/administracion`, `/usuarios`, `/roles`, `/proyectos`, `/permisos`) rendered solely when the access context reports `isSuperadmin`. The routes and module screens are not built in Phase 2.



## 2. Tables and fields

Types first: `financial_level` as constrained `smallint CHECK (between 0 and 4)` — preferred over enum because it is ordinal and comparable (`>= 3`), and adding levels later needs no type migration. Status fields use enums or CHECK-constrained text (project status, location status, member state).

- **organizations**: id, name, legal_name, tax_id?, country, timezone, default_currency, is_active, created_at.
- **business_units**: id, organization_id FK, name, code, is_active, created_at. Unique (organization_id, code).
- **profiles**: id PK/FK → auth.users (CASCADE for the profile row only, while business tables reference `profiles` with RESTRICT/SET NULL so history survives), first_name, last_name, phone?, avatar_path?, job_title?, employee_code?, is_active, created_at, updated_at. Created by an `AFTER INSERT ON auth.users` trigger (SECURITY DEFINER). Deactivation (`is_active = false`) is the normal offboarding path, not deletion. **No unrestricted UPDATE grant to `authenticated`** — RLS is row-level, not column-level, so self-editing goes through a narrow protected function `public.update_own_profile(first_name, last_name, phone, avatar_path)` (SECURITY DEFINER, `search_path = ''`, writes only those columns for `auth.uid()`, EXECUTE granted to `authenticated`). `is_active`, `employee_code` and any future authorization field are writable only through Superadmin-protected paths.
- **roles**: id, organization_id nullable (NULL = system role shared by all orgs), code, name, default_financial_level, is_system_role, is_active. Unique (coalesce(organization_id), code). Seeded with the 12 approved DFN business roles: Director General, Director Construcción/Operaciones, Gerente/Coordinador de Proyecto, Superintendente de Obra, Residente de Obra, Supervisor, Maestro de Obra, Control de Obra/Costos, Compras, Almacén, Contabilidad, Administración. Platform Superadmin is not in this catalog.
- **permissions**: id, code unique, name, category, description.
- **role_permissions**: role_id, permission_id, PK(role_id, permission_id).
- **organization_members**: id, organization_id, user_id, role_id, financial_level, is_active, starts_at, ends_at?, created_at, created_by. Partial unique index on (organization_id, user_id) WHERE is_active.
- **projects**: id, organization_id, business_unit_id?, project_code, name, client_name, description, project_type, address, latitude, longitude, contract_start_date, contract_end_date, actual_start_date?, actual_end_date?, status, cover_photo_path?, manager_user_id?, created_at, archived_at?. Unique (organization_id, project_code). No money columns.
- **project_financials**: project_id PK/FK, approved_budget, contract_value, approved_change_value, forecast_cost, target_margin, currency, updated_at, updated_by. numeric(16,2).
- **project_members**: id, project_id, user_id, role_id, financial_level, starts_at, ends_at?, is_active, assigned_by, created_at. Partial unique (project_id, user_id) WHERE is_active.
- **project_member_permission_overrides**: id, project_member_id, permission_id, allowed bool, valid_from, valid_until?, granted_by, created_at. Unique (project_member_id, permission_id, valid_from).
- **project_locations**: id, project_id, parent_location_id? FK → self (ON DELETE RESTRICT), location_type, code, name, description, sort_order, status, created_at, created_by, archived_at?. Indexes on (project_id, parent_location_id) and (project_id, sort_order). CHECK (id <> parent_location_id) blocks self-parenting; deeper cycles are prevented by a BEFORE INSERT/UPDATE trigger that walks ancestors recursively and raises on revisit, plus a CHECK that parent belongs to the same project.
- **audit_logs**: id, organization_id, project_id?, actor_user_id, actor_name_snapshot, action, entity_type, entity_id, old_values jsonb, new_values jsonb, ip_address?, user_agent?, created_at. Append-only: no UPDATE/DELETE grants or policies for `authenticated`; writes happen through SECURITY DEFINER triggers/functions.

Delete behavior: RESTRICT for roles, projects, memberships referenced by history; SET NULL for optional actor references; CASCADE only for overrides under their member row and profile under auth user.

## 3. Relationship diagram

```text
auth.users 1─1 profiles
organizations 1─* business_units
organizations 1─* organization_members *─1 roles
organizations 1─* projects *─0..1 business_units
projects 1─0..1 project_financials
projects 1─* project_members *─1 roles
project_members 1─* project_member_permission_overrides *─1 permissions
projects 1─* project_locations ─* (self, recursive)
roles *─* permissions (role_permissions)
organizations 1─* audit_logs *─0..1 projects
```

## 4. Access resolution algorithm

1. `uid = auth.uid()`; require an active profile.
2. Org context: active `organization_members` row (starts_at <= now, ends_at null or > now) → org role + org financial_level.
3. Project context: active `project_members` row for that project → project role + project financial_level.
4. Effective permission for (user, project) = project role permissions ∪ org role permissions, then apply overrides valid at now(): explicit `allowed = false` wins over any grant; `allowed = true` adds.
5. Project visibility = has an active project membership OR org role holds `project.view` at org scope (Director, Contabilidad).
6. Financial: effective_level = max(org level, project level); a `financial.*` read requires both the permission and the level threshold (contract F3, cost F2, margin/collection F4). `project_financials` SELECT requires level >= 3 plus `financial.contract_view`.

## 5. RLS strategy (all tables: RLS enabled, explicit GRANTs, no `anon` grants)

| Table | SELECT | INSERT/UPDATE/DELETE |
|---|---|---|
| organizations | active org member | `user.manage` only |
| business_units | active org member | `user.manage` |
| profiles | self, or same-org member | self (limited cols); admin via `user.manage` |
| organization_members | self rows, or `user.manage` | `user.manage` only |
| roles / permissions / role_permissions | any authenticated org member (read-only catalog) | none from client |
| projects | `private.can_access_project(id)` | `project.edit` / `user.manage` |
| project_financials | level >= 3 + `financial.contract_view` | F4 + explicit permission |
| project_members | own rows or `user.manage` in that project | `user.manage` |
| overrides | via parent member visibility | `user.manage` |
| project_locations | `private.can_access_project(project_id)` | `project.edit` |
| audit_logs | `audit.view` scoped to org/project, or Superadmin | INSERT only via definer functions; no UPDATE/DELETE |
| private.platform_admins | none from the client (no grants, not in the API) | none from the client; managed by migration or a verified server function |

Each administrative table also carries an explicit `private.is_superadmin()` policy for write operations, in addition to the `user.manage` business path. No client-side database role has BYPASSRLS.

Dependency graph (avoids recursion): policies on business tables call `private.*` SECURITY DEFINER helpers, which read membership tables directly with RLS bypassed. Membership tables' own policies use only `auth.uid()` comparisons, `private.is_superadmin()`, or a single non-recursive `private.has_org_permission` that reads `organization_members` as definer — never a policy on the same table it queries. `private.platform_admins` has no policies reachable from the client at all, so `is_superadmin` cannot recurse.

## 6. Helper functions (schema `private`)

`is_superadmin(user_id)`, `is_organization_member(org)`, `has_org_permission(code)`, `is_project_member(project)`, `can_access_project(project)`, `has_project_permission(project, code)`, `financial_access_level(project)`, `current_org()`. All STABLE, SECURITY DEFINER, `set search_path = ''`, fully qualified, EXECUTE revoked from `public`/`anon`/`authenticated`. Reason: single source of truth, keeps policies short, prevents recursive membership evaluation, and keeps admin status unreadable by ordinary users.


## 7. Migration order (small, reviewable)

1. `private` schema + shared types/CHECK domains + `updated_at` trigger fn.
2. organizations, business_units.
3. profiles + auth.users trigger.
4. roles, permissions, role_permissions.
5. organization_members.
6. projects, project_financials.
7. project_members, overrides.
8. project_locations (+ cycle trigger).
9. audit_logs + audit write function/triggers.
10. `private.platform_admins`.
11. private helper functions (including `is_superadmin`).
12. GRANTs + RLS policies for all of the above, including the Superadmin administrative policies.
13. Seed reference data.

Each step is a separate migration presented for approval.

## 8. Permission catalog (including Materials/Warehouse readiness)

The catalog is seeded in full in Phase 2 even though several codes have no screen yet. Categories: `project`, `user`, `audit`, `financial`, `expense`, `vendor_invoice`, `client_invoice`, `reimbursement`, `material_request`, `warehouse`, `shipment`, `material_receipt`, `material_issue`.

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

Initial users: created manually in the Supabase dashboard — no privileged admin-user code in this phase. Memberships and the first `platform_admins` row are attached by a small, reviewed SQL statement referencing emails, not by the app. No personal emails or passwords are stored in the plan or in seed SQL.

Real test identity matrix (all non-Superadmin unless stated):

| Identity | Role | Financial level | Platform Superadmin |
|---|---|---|---|
| Diego (admin account) | platform administration only | none by itself; Director General + F4 may be assigned explicitly for business testing | Yes |
| Pablo Avilés | Director General | F4 | No |
| Miguel Ángel Tobón | Superintendente de Obra | F3 | No |
| Diego (second account) | Residente de Obra | F2 | No |
| Ricardo | Maestro de Obra | F1 | No |
| Cecy | Contabilidad | F2 | No |
| Warehouse test user | Almacén | F0/F1 | No |

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

Business access: Director reads all org projects and financials; Residente reads assigned project, 0 rows for unrelated project; Maestro assigned project only and `project_financials` returns 0 rows; Contabilidad cross-project financial reads at its level; Anonymous 0 rows everywhere. Plus expired membership → no access; inactive membership → no access; override deny removes a role-granted permission; override allow grants one; unauthorized project URL renders the unavailable state; direct PostgREST query with a known UUID returns empty.

New role tests:
- Cecy (Contabilidad, F2): holds the accounting permission codes; `project_financials` contract/margin reads return 0 rows at F2; holds no warehouse or shipment permission.
- Warehouse user (Almacén, F0/F1): holds only warehouse/shipment codes; `project_financials` returns 0 rows; cannot read contract value, unit prices, margin or collections; cannot approve material requests.
- Superintendente (Miguel Ángel Tobón, F3): holds review/approve/reject/return codes; no warehouse codes; no platform administration.
- Maestro (Ricardo, F1): requester/receiver codes only; no approval, warehouse or financial codes.

Platform administration (run with the two real accounts):
- Account A (Superadmin): can perform permitted administrative writes through the approved protected paths; sees the administration navigation; reads business/financial data only through its separately assigned Director General + F4 membership, except the documented audit-read policy.
- Director non-Superadmin: F4 grants no administration; cannot change roles, permissions, memberships or financial levels.
- Account B (Residente): `private.platform_admins` is unreadable (function/table not in the API); admin navigation hidden and admin URLs render unauthorized; cannot assign roles, modify memberships, change financial levels or view unrelated projects; direct Supabase API attempts blocked by grants/RLS.
- Privilege escalation (all must fail): insert self into platform_admins; modify own organization_members row; change own role_id; raise own financial_level; insert a project_members row for self; insert a permission override for self; grant self any material_request approval or warehouse permission.



## 13. Risks and edge cases

RLS recursion on membership tables (mitigated by the definer helpers); policy performance on hot paths (indexes on membership `(user_id, project_id) WHERE is_active`); trigger-created profiles failing silently for dashboard users; users with org role but no project membership; clock/timezone handling for starts_at/ends_at; accidental `anon` grants; auth user deletion orphaning history (use deactivation); seeded-but-unused permission codes drifting from the future Materials schema (mitigated by section 8b being the contract for that module); shared warehouse logins breaking attributability in production.

## 14. Cost

Supabase Free, current Lovable plan, GitHub Free only. No new paid services and no new frontend dependencies.

## 15. Acceptance checklist

- The 13 public core tables plus `private.platform_admins` exist with PKs, FKs, uniques, checks, indexes and restrictive deletes.
- RLS enabled and explicit GRANTs on every public table; `anon` cannot read any business data; `private.platform_admins` is not reachable from the Data API.
- Helper functions live in `private`, are SECURITY DEFINER with empty search_path, and are not exposed via the Data API.
- Superadmin is modeled independently of business role and financial level; F4 and Director General grant no administration.
- No BYPASSRLS database role is used from the browser; no service-role credential appears in frontend code.
- Profile auto-created for dashboard-created auth users.
- Real login, logout and password reset work; no sign-up UI exists.
- Role/permission/financial-level resolution comes from the database, not from role-name checks in the client.
- The full permission catalog is seeded, including the accounting and Materials/Warehouse codes listed in section 8, with the stated role defaults.
- Superintendente de Obra and Almacén exist as real seeded roles; Almacén defaults to F0/F1 with no `financial.*` permissions.
- Contabilidad is seeded at F2 with granular accounting permissions and no automatic F4.
- The seven real test identities are configured with the stated roles and levels; no personal emails or passwords appear in seeds or the plan.
- Two distinct real Supabase accounts (Superadmin and Residente) exist and pass their matrix rows; all privilege-escalation attempts fail.
- Every item of the security test matrix passes, including the new Contabilidad, Almacén, Superintendente and Maestro rows.
- Navigation config is permission-driven and ready for `/administracion`, `/proyecto/$projectId/materiales` and `/almacen`, but none of those screens or routes are built.
- Phase 1 shell, routes and components still render for all roles with real data.
- Demo session/role switcher removed only after real auth is confirmed.
- No operational or Materials/Warehouse tables created; typecheck and build clean.


