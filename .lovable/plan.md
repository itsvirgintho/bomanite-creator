# DFN Control — Foundation Phase 2

Core backend + real authorization. Replaces the mocked identity/project foundation with Supabase Auth, real membership, RBAC, financial levels, locations, audit and RLS — while preserving the Phase 1 shell, routes and components.

## 1. Architecture

- Identity: Supabase Auth (email/password only, no public sign-up). `profiles` mirrors `auth.users` 1:1.
- Authorization resolved in the database, never in the UI. Frontend reads an "access context" (profile + org membership + project memberships + effective permissions + financial level) exposed through server functions and RLS-protected views.
- Two membership planes: organization-level (Director, Contabilidad, Administración) and project-level (Residente, Supervisor, Maestro, etc.). Project role wins inside a project; org role provides global reach.
- Permissions are a catalog + role mappings + per-project-member overrides. No role-name string checks in code; the client uses permission codes only for UI visibility.
- All privileged helper logic lives in a non-exposed `private` schema, `SECURITY DEFINER`, `set search_path = ''`, fully qualified names, `REVOKE EXECUTE FROM anon, authenticated` where possible (policies run as definer-owner and can still call them).
- Sensitive money lives only in `project_financials`, gated separately from `projects`.
- **Platform administration is a third, independent plane** (`private.platform_admins`), unrelated to business role and financial level. See section 2b.

### 2b. Platform Superadmin layer

`private.platform_admins` (not in `public`, not exposed through the Data API, no grants to `anon`/`authenticated`): id, user_id FK → auth.users (ON DELETE CASCADE), admin_level (CHECK in ('superadmin') for now, extensible), is_active, created_at, created_by. Partial unique on (user_id) WHERE is_active.

Separation rules:
- Superadmin ≠ Director General, ≠ F4, ≠ any org or project role. F4 never implies administration; administration never implies financial visibility.
- A Superadmin who must also see business data receives an explicit organization membership (e.g. Director General + F4). Business reads stay governed by the normal membership/financial policies.
- Helper: `private.is_superadmin(_user_id uuid default auth.uid())` — STABLE, SECURITY DEFINER, `search_path = ''`, fully qualified `private.platform_admins`, returns true only for an active row. `REVOKE EXECUTE ON FUNCTION private.is_superadmin FROM public, anon, authenticated;` policies call it as the definer owner. It returns a boolean only — it can never be used to read or mutate data by itself.
- RLS behavior: no BYPASSRLS role is ever used from the browser. Administration is expressed as additional explicit policies on the administrative tables (organizations, business_units, profiles activation, organization_members, project_members, overrides, roles, role_permissions, projects, project_financials write, audit read) with `USING (private.is_superadmin())`. Superadmin does **not** get a blanket read of every business table unless a policy documents it (audit read is the documented exception).
- Auth user management (future, not built in Phase 2): Superadmin browser → authenticated TanStack server function → verify `private.is_superadmin()` server-side → call the Supabase Auth admin API with the service-role key held only in the server runtime → create/invite/deactivate. The secret never reaches frontend code, and the client never calls the admin API directly. For Phase 2, test users are created manually in the Supabase dashboard.
- Navigation readiness only: `src/config/navigation.ts` gains an `admin` group (`/administracion`, `/usuarios`, `/roles`, `/proyectos`, `/permisos`) rendered solely when the access context reports `isSuperadmin`. The routes and module screens are not built in Phase 2.



## 2. Tables and fields

Types first: `financial_level` as constrained `smallint CHECK (between 0 and 4)` — preferred over enum because it is ordinal and comparable (`>= 3`), and adding levels later needs no type migration. Status fields use enums or CHECK-constrained text (project status, location status, member state).

- **organizations**: id, name, legal_name, tax_id?, country, timezone, default_currency, is_active, created_at.
- **business_units**: id, organization_id FK, name, code, is_active, created_at. Unique (organization_id, code).
- **profiles**: id PK/FK → auth.users (ON DELETE RESTRICT is impossible on auth.users; use ON DELETE CASCADE for the profile row only, while business tables reference `profiles` with RESTRICT/SET NULL so history survives), first_name, last_name, phone?, avatar_path?, job_title?, employee_code?, is_active, created_at, updated_at. Created by an `AFTER INSERT ON auth.users` trigger (SECURITY DEFINER) — Supabase-native, no admin code, works for dashboard-created users. Deactivation (`is_active = false`) is the normal offboarding path, not deletion.
- **roles**: id, organization_id nullable (NULL = system role shared by all orgs), code, name, default_financial_level, is_system_role, is_active. Unique (coalesce(organization_id), code). Seeded with the 11 approved DFN roles.
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

## 8. Seed / reference data

Seed only: the DFN Desarrollo e Infraestructura organization, the two business units, the 11 roles with default financial levels, the full permission catalog, and role→permission mappings. No fake projects or financials. The org UUID is never hard-coded in the frontend; the client resolves it from the user's `organization_members` row.

Initial users: created manually in the Supabase dashboard — no privileged admin-user code in this phase. Memberships and the first `platform_admins` row are attached by a small, reviewed SQL statement referencing emails, not by the app.

Two real owner accounts (mandatory for Phase 2 testing, never simulated with DemoRoleSwitcher once real auth is on):
- **Account A — Superadmin**: active row in `private.platform_admins` (`superadmin`), plus an explicitly assigned Director General organization membership at F4 for business testing.
- **Account B — Residente**: no platform-admin row, membership only in the selected test project with the Residente de Obra role and an explicitly configured financial level (F2 or F3), no access to administration or unrelated projects.

Optional additional test identities: Maestro and Contabilidad, configured the same way.


## 9. Auth flow and mock-to-real migration

Auth: `/auth` becomes real `signInWithPassword`; real `signOut` (cancel queries, clear cache, replace-navigate to `/auth`); password reset via Supabase's built-in reset email (free tier, no paid service). No sign-up UI.

Staged migration, demo system stays until each stage is green:
1. Add a real `AuthContext` (Supabase session) alongside the mock session; app still uses mock.
2. Add server functions returning access context and authorized project list.
3. Switch `SessionContext` internals to real data behind the same interface, so `AppShell`, `SidebarNav`, `MobileBottomNav`, `ProjectSwitcher` and role homes stay unchanged.
4. Move protected routes under the managed `_authenticated` gate; `/auth` and `/` stay public.
5. `ProjectSwitcher` and `/proyecto/$projectId` load only authorized projects; an unauthorized/unknown id renders "Proyecto no disponible o sin acceso" (no content leak, no distinction fishing).
6. Once verified, remove `DemoRoleSwitcher`, demo users/projects from `src/mocks`, and the mock branches — keeping only clearly labeled demo data for still-mocked operational widgets, or removing the "Datos de demostración" notice where data is now real.

## 10. Security test matrix

Director: reads all org projects; reads financials. Residente: reads assigned project, 0 rows for unrelated project. Maestro: assigned project only; `project_financials` returns 0 rows. Contabilidad: cross-project financial reads allowed at its level. Anonymous: 0 rows on every table. Plus: expired membership (ends_at past) → no access; inactive membership → no access; override deny removes a role-granted permission; override allow grants one; direct unauthorized project URL renders the unavailable state; direct PostgREST query with a known UUID returns empty.

## 11. Risks and edge cases

RLS recursion on membership tables (mitigated by the definer helpers); policy performance on hot paths (indexes on membership `(user_id, project_id) WHERE is_active`); trigger-created profiles failing silently for dashboard users; users with org role but no project membership; clock/timezone handling for starts_at/ends_at; accidental `anon` grants; auth user deletion orphaning history (use deactivation).

## 12. Cost

Supabase Free, current Lovable plan, GitHub Free only. No new paid services and no new frontend dependencies.

## 13. Acceptance checklist

- All 13 tables exist with PKs, FKs, uniques, checks, indexes and restrictive deletes.
- RLS enabled and explicit GRANTs on every table; `anon` cannot read any business data.
- Helper functions live in `private`, are SECURITY DEFINER with empty search_path, and are not exposed via the Data API.
- Profile auto-created for dashboard-created auth users.
- Real login, logout and password reset work; no sign-up UI exists.
- Role/permission/financial-level resolution comes from the database, not from role-name checks in the client.
- Every item of the security test matrix passes.
- Phase 1 shell, routes and components still render for all four roles with real data.
- Demo session/role switcher removed only after real auth is confirmed.
- No operational module tables created; typecheck and build clean.
