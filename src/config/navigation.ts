/**
 * Navegación declarativa basada en el contexto REAL de autorización
 * (public.get_my_authorization_context()).
 *
 * UI visibility only — NOT authorization. La autoridad real es RLS en la base
 * de datos. Aquí solo decidimos qué enlaces mostramos.
 *
 * Reglas duras:
 * - Nunca usar roles demo, DEMO_USERS, GLOBAL_ROLES ni financial_level.
 * - El acceso financiero SIEMPRE proviene de activeProject.financial_access.*
 * - is_superadmin por sí solo NO otorga navegación de negocio.
 */
import {
  Building2,
  CalendarRange,
  ClipboardList,
  FileSpreadsheet,
  Layers,
  LayoutGrid,
  Map,
  Receipt,
  TriangleAlert,
  User,
  Wallet,
} from "lucide-react";
import type { ComponentType } from "react";
import type { AuthorizationContext, AuthzProject } from "@/types/authorization";

export type NavSurface = "desktop" | "mobile" | "both";

export interface NavVisibilityInput {
  context: AuthorizationContext | null | undefined;
  activeProject: AuthzProject | null | undefined;
}

export interface NavItem {
  id: string;
  label: string;
  /** Etiqueta corta para la navegación inferior móvil. */
  shortLabel?: string;
  /** Ruta TanStack. Las rutas de proyecto usan el segmento $projectId. */
  to: string;
  icon: ComponentType<{ className?: string }>;
  requiresProject?: boolean;
  surface: NavSurface;
  group: "principal" | "operacion" | "control" | "cuenta";
  /** Predicado declarativo de visibilidad de UI (no es autorización). */
  visible: (input: NavVisibilityInput) => boolean;
}

/** Permisos de organización que habilitan la vista global de contabilidad. */
export const ACCOUNTING_ORG_PERMISSIONS = [
  "expense.view_all",
  "vendor_invoice.view",
  "client_invoice.view",
  "reimbursement.view",
] as const;

export const PORTFOLIO_ORG_PERMISSION = "portfolio.view";

/** ¿Alguna organización otorga alguno de estos permisos? */
export function hasOrgPermission(
  context: AuthorizationContext | null | undefined,
  permissions: readonly string[],
): boolean {
  if (!context) return false;
  return context.organizations.some((organization) =>
    permissions.some((permission) => organization.permissions.includes(permission)),
  );
}

/** Autoridad de portafolio: permiso explícito, nunca is_superadmin. */
export function hasPortfolioAccess(context: AuthorizationContext | null | undefined): boolean {
  return hasOrgPermission(context, [PORTFOLIO_ORG_PERMISSION]);
}

/** Acceso global de contabilidad por permisos explícitos, nunca por rol. */
export function hasAccountingAccess(context: AuthorizationContext | null | undefined): boolean {
  return hasOrgPermission(context, ACCOUNTING_ORG_PERMISSIONS);
}

/**
 * Regla TRANSITORIA de UI para módulos de proyecto que aún no tienen su código
 * de permiso definitivo en el backend: se muestran cuando existe un proyecto
 * autorizado activo. Esto NO es seguridad; RLS sigue siendo la autoridad.
 */
const transitionalProjectItem = ({ activeProject }: NavVisibilityInput): boolean =>
  Boolean(activeProject);

export const NAV_ITEMS: NavItem[] = [
  {
    id: "portafolio",
    label: "Portafolio",
    to: "/portafolio",
    icon: LayoutGrid,
    surface: "both",
    group: "principal",
    visible: ({ context }) => hasPortfolioAccess(context),
  },
  {
    id: "proyecto",
    label: "Resumen del proyecto",
    shortLabel: "Proyecto",
    to: "/proyecto/$projectId",
    icon: Building2,
    requiresProject: true,
    surface: "both",
    group: "principal",
    visible: transitionalProjectItem,
  },
  {
    id: "reportes",
    label: "Reportes",
    to: "/proyecto/$projectId/reportes",
    icon: ClipboardList,
    requiresProject: true,
    surface: "both",
    group: "operacion",
    visible: transitionalProjectItem,
  },
  {
    id: "avance",
    label: "Avance",
    to: "/proyecto/$projectId/avance",
    icon: Layers,
    requiresProject: true,
    surface: "both",
    group: "operacion",
    visible: transitionalProjectItem,
  },
  {
    id: "incidencias",
    label: "Incidencias",
    to: "/proyecto/$projectId/incidencias",
    icon: TriangleAlert,
    requiresProject: true,
    surface: "both",
    group: "operacion",
    visible: transitionalProjectItem,
  },
  {
    id: "planos",
    label: "Planos",
    to: "/proyecto/$projectId/planos",
    icon: Map,
    requiresProject: true,
    surface: "both",
    group: "operacion",
    visible: transitionalProjectItem,
  },
  {
    id: "programa",
    label: "Programa",
    to: "/proyecto/$projectId/programa",
    icon: CalendarRange,
    requiresProject: true,
    surface: "desktop",
    group: "control",
    visible: transitionalProjectItem,
  },
  {
    id: "gastos",
    label: "Gastos",
    to: "/proyecto/$projectId/gastos",
    icon: Receipt,
    requiresProject: true,
    surface: "both",
    group: "control",
    // Financiero: SOLO financial_access.cost — nunca financial_level.
    visible: ({ activeProject }) => Boolean(activeProject?.financial_access.cost),
  },
  {
    id: "estimaciones",
    label: "Estimaciones",
    to: "/proyecto/$projectId/estimaciones",
    icon: FileSpreadsheet,
    requiresProject: true,
    surface: "desktop",
    group: "control",
    // Financiero: SOLO financial_access.contract — nunca financial_level.
    visible: ({ activeProject }) => Boolean(activeProject?.financial_access.contract),
  },
  {
    id: "contabilidad",
    label: "Contabilidad",
    shortLabel: "Conta.",
    to: "/contabilidad",
    icon: Wallet,
    surface: "both",
    group: "principal",
    visible: ({ context }) => hasAccountingAccess(context),
  },
  {
    id: "perfil",
    label: "Perfil",
    to: "/perfil",
    icon: User,
    surface: "both",
    group: "cuenta",
    visible: () => true,
  },
];

export interface NavFilter extends NavVisibilityInput {
  surface: "desktop" | "mobile";
}

/** UI visibility only — NOT authorization. */
export function getNavItems({ context, activeProject, surface }: NavFilter): NavItem[] {
  if (!context) return [];
  return NAV_ITEMS.filter((item) => {
    if (item.surface !== "both" && item.surface !== surface) return false;
    if (item.requiresProject && !activeProject) return false;
    return item.visible({ context, activeProject });
  });
}

export const MOBILE_NAV_LIMIT = 5;
