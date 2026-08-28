import type { Role } from "@/types/domain";

export const ROLE_LABELS: Record<Role, string> = {
  director_general: "Director General",
  residente: "Residente de Obra",
  maestro: "Maestro de Obra",
  contabilidad: "Contabilidad",
};

export const ROLE_ORDER: Role[] = [
  "director_general",
  "residente",
  "maestro",
  "contabilidad",
];

/** Roles that operate across projects and can exist without an active project. */
export const GLOBAL_ROLES: Role[] = ["director_general", "contabilidad"];
