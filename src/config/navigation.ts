/**
 * Navegación declarativa por rol.
 * UI visibility only — NOT authorization.
 * La autorización real se aplicará con Supabase Auth, membresía de proyecto y RLS.
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
import type { FinancialLevel, Role } from "@/types/domain";

export type NavSurface = "desktop" | "mobile" | "both";

export interface NavItem {
  id: string;
  label: string;
  /** Ruta TanStack. Las rutas de proyecto usan el segmento $projectId. */
  to: string;
  icon: ComponentType<{ className?: string }>;
  roles: Role[];
  /** Nivel financiero mínimo para mostrar el item (solo visibilidad de UX). */
  minFinancialLevel?: FinancialLevel;
  requiresProject?: boolean;
  surface: NavSurface;
  group: "principal" | "operacion" | "control" | "cuenta";
}

export const NAV_ITEMS: NavItem[] = [
  {
    id: "portafolio",
    label: "Portafolio",
    to: "/portafolio",
    icon: LayoutGrid,
    roles: ["director_general"],
    minFinancialLevel: 4,
    surface: "both",
    group: "principal",
  },
  {
    id: "proyecto",
    label: "Resumen del proyecto",
    to: "/proyecto/$projectId",
    icon: Building2,
    roles: ["director_general", "residente", "maestro"],
    requiresProject: true,
    surface: "both",
    group: "principal",
  },
  {
    id: "reportes",
    label: "Reportes",
    to: "/proyecto/$projectId/reportes",
    icon: ClipboardList,
    roles: ["director_general", "residente", "maestro"],
    requiresProject: true,
    surface: "both",
    group: "operacion",
  },
  {
    id: "avance",
    label: "Avance",
    to: "/proyecto/$projectId/avance",
    icon: Layers,
    roles: ["director_general", "residente"],
    requiresProject: true,
    surface: "both",
    group: "operacion",
  },
  {
    id: "incidencias",
    label: "Incidencias",
    to: "/proyecto/$projectId/incidencias",
    icon: TriangleAlert,
    roles: ["director_general", "residente", "maestro"],
    requiresProject: true,
    surface: "both",
    group: "operacion",
  },
  {
    id: "planos",
    label: "Planos",
    to: "/proyecto/$projectId/planos",
    icon: Map,
    roles: ["director_general", "residente", "maestro"],
    requiresProject: true,
    surface: "both",
    group: "operacion",
  },
  {
    id: "programa",
    label: "Programa",
    to: "/proyecto/$projectId/programa",
    icon: CalendarRange,
    roles: ["director_general", "residente"],
    requiresProject: true,
    surface: "desktop",
    group: "control",
  },
  {
    id: "gastos",
    label: "Gastos",
    to: "/proyecto/$projectId/gastos",
    icon: Receipt,
    roles: ["director_general", "residente", "maestro"],
    requiresProject: true,
    minFinancialLevel: 1,
    surface: "both",
    group: "control",
  },
  {
    id: "estimaciones",
    label: "Estimaciones",
    to: "/proyecto/$projectId/estimaciones",
    icon: FileSpreadsheet,
    roles: ["director_general", "residente"],
    requiresProject: true,
    minFinancialLevel: 3,
    surface: "desktop",
    group: "control",
  },
  {
    id: "contabilidad",
    label: "Contabilidad",
    to: "/contabilidad",
    icon: Wallet,
    roles: ["director_general", "contabilidad"],
    minFinancialLevel: 3,
    surface: "both",
    group: "principal",
  },
  {
    id: "perfil",
    label: "Perfil",
    to: "/perfil",
    icon: User,
    roles: ["director_general", "residente", "maestro", "contabilidad"],
    surface: "both",
    group: "cuenta",
  },
];

export interface NavFilter {
  role: Role;
  financialLevel: FinancialLevel;
  hasProject: boolean;
  surface: "desktop" | "mobile";
}

/** UI visibility only — NOT authorization. */
export function getNavItems({ role, financialLevel, hasProject, surface }: NavFilter): NavItem[] {
  return NAV_ITEMS.filter((item) => {
    if (!item.roles.includes(role)) return false;
    if (item.minFinancialLevel !== undefined && financialLevel < item.minFinancialLevel) return false;
    if (item.requiresProject && !hasProject) return false;
    if (item.surface !== "both" && item.surface !== surface) return false;
    return true;
  });
}

export const MOBILE_NAV_LIMIT = 5;
