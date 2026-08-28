/**
 * Authorization context returned by public.get_my_authorization_context().
 * The database is the authority: these types only describe the payload shape.
 * Never derive authorization decisions in TypeScript beyond rendering.
 */

export interface AuthzProfile {
  id: string;
  first_name: string | null;
  last_name: string | null;
  phone: string | null;
  avatar_path: string | null;
  job_title: string | null;
  employee_code: string | null;
}

export interface AuthzRole {
  id: string;
  code: string;
  name: string;
}

export interface AuthzMembership {
  role: AuthzRole | null;
  financial_level: number;
}

export interface AuthzOrganization {
  id: string;
  name: string;
  legal_name: string | null;
  country: string;
  timezone: string;
  default_currency: string;
  membership: AuthzMembership;
  permissions: string[];
}

export interface AuthzFinancialAccess {
  cost: boolean;
  contract: boolean;
  margin: boolean;
  collection: boolean;
}

export interface AuthzProject {
  id: string;
  organization_id: string;
  business_unit_id: string | null;
  code: string;
  name: string;
  client_name: string | null;
  location_label: string | null;
  status: string;
  start_date: string | null;
  end_date: string | null;
  direct_membership: AuthzMembership | null;
  permissions: string[];
  financial_access: AuthzFinancialAccess;
}

export interface AuthorizationContext {
  version: number;
  profile: AuthzProfile;
  is_superadmin: boolean;
  organizations: AuthzOrganization[];
  projects: AuthzProject[];
}

/** Full name helper for display only. */
export function profileDisplayName(profile: AuthzProfile | null | undefined): string {
  if (!profile) return "Usuario";
  const name = [profile.first_name, profile.last_name].filter(Boolean).join(" ").trim();
  return name.length > 0 ? name : "Usuario";
}
