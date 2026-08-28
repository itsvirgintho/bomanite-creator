/**
 * DEMO DATA ONLY — DFN Control Foundation Phase 1.
 * Todo el contenido de este archivo es ficticio y sirve para validar la UI.
 * No representa datos reales de obra, contratos ni finanzas.
 * Se eliminará cuando se conecte Supabase.
 */
import type {
  AccountingRow,
  AttentionItem,
  DemoUser,
  MaestroDay,
  Project,
  ResidentSummary,
  Role,
} from "@/types/domain";

export const DEMO_DATA_LABEL = "Datos de demostración";

export const DEMO_PROJECTS: Project[] = [
  {
    id: "maraluna",
    code: "DFN-2401",
    name: "Maraluna",
    client: "Grupo Costa Norte",
    location: "Mazatlán, Sinaloa",
    health: "at_risk",
    plannedProgress: 62,
    actualProgress: 54.3,
    startDate: "2025-09-01",
    endDate: "2026-11-30",
    elapsedDays: 361,
    remainingDays: 94,
    workforceOnSite: 78,
    contractAmount: 184500000,
    estimatedAmount: 96200000,
    invoicedAmount: 88400000,
    collectedAmount: 71300000,
  },
  {
    id: "puerta-sierra",
    code: "DFN-2408",
    name: "Puerta Sierra",
    client: "Inmobiliaria Altavista",
    location: "Culiacán, Sinaloa",
    health: "on_plan",
    plannedProgress: 38,
    actualProgress: 39.6,
    startDate: "2026-01-15",
    endDate: "2027-03-20",
    elapsedDays: 225,
    remainingDays: 204,
    workforceOnSite: 41,
    contractAmount: 92750000,
    estimatedAmount: 34100000,
    invoicedAmount: 31900000,
    collectedAmount: 28600000,
  },
  {
    id: "corredor-norte",
    code: "DFN-2312",
    name: "Corredor Norte Tramo 2",
    client: "Gobierno del Estado",
    location: "Los Mochis, Sinaloa",
    health: "critical",
    plannedProgress: 81,
    actualProgress: 64.1,
    startDate: "2025-03-10",
    endDate: "2026-09-30",
    elapsedDays: 536,
    remainingDays: 33,
    workforceOnSite: 112,
    contractAmount: 268300000,
    estimatedAmount: 168900000,
    invoicedAmount: 151200000,
    collectedAmount: 112400000,
  },
];

export function getDemoProject(projectId: string | undefined): Project | undefined {
  return DEMO_PROJECTS.find((project) => project.id === projectId);
}

export const DEMO_USERS: Record<Role, DemoUser> = {
  director_general: {
    id: "u-dg",
    name: "Ricardo Fuentes",
    email: "ricardo.fuentes@dfn.mx",
    role: "director_general",
    financialLevel: 4,
    assignedProjectIds: [],
  },
  residente: {
    id: "u-res",
    name: "Diana Nevárez",
    email: "diana.nevarez@dfn.mx",
    role: "residente",
    financialLevel: 2,
    assignedProjectIds: ["maraluna", "puerta-sierra"],
  },
  maestro: {
    id: "u-mo",
    name: "Jesús Angulo",
    email: "jesus.angulo@dfn.mx",
    role: "maestro",
    financialLevel: 0,
    assignedProjectIds: ["maraluna"],
  },
  contabilidad: {
    id: "u-cont",
    name: "Paola Márquez",
    email: "paola.marquez@dfn.mx",
    role: "contabilidad",
    financialLevel: 3,
    assignedProjectIds: [],
  },
};

export const DEMO_DIRECTOR_ATTENTION: AttentionItem[] = [
  {
    id: "dg-1",
    label: "Proyectos con desviación crítica",
    count: 1,
    severity: "danger",
    detail: "Corredor Norte Tramo 2 · −16.9 pts vs programa",
    drilldownTo: "/proyecto/corredor-norte",
  },
  {
    id: "dg-2",
    label: "Estimaciones esperando aprobación interna",
    count: 3,
    severity: "warning",
    detail: "Maraluna, Corredor Norte",
  },
  {
    id: "dg-3",
    label: "Cobranza vencida",
    count: 2,
    severity: "warning",
    detail: "Demo · $38.8 M pendientes de cobro",
  },
  {
    id: "dg-4",
    label: "Incidencias críticas abiertas",
    count: 5,
    severity: "danger",
    detail: "En 2 proyectos del portafolio",
  },
  {
    id: "dg-5",
    label: "Contratos por vencer en 60 días",
    count: 1,
    severity: "info",
    detail: "Corredor Norte Tramo 2",
  },
];

export const DEMO_RESIDENT_SUMMARIES: ResidentSummary[] = [
  {
    projectId: "maraluna",
    attention: [
      {
        id: "res-1",
        label: "Reportes por revisar",
        count: 4,
        severity: "warning",
        detail: "Cuadrillas de estructura y albañilería",
        drilldownTo: "reportes",
      },
      {
        id: "res-2",
        label: "Cantidades por validar",
        count: 11,
        severity: "warning",
        detail: "Torre B niveles 4–6",
        drilldownTo: "avance",
      },
      {
        id: "res-3",
        label: "Gastos por revisar",
        count: 6,
        severity: "info",
        detail: "Demo · $84,200 en comprobación",
        drilldownTo: "gastos",
      },
      {
        id: "res-4",
        label: "Incidencias vencidas",
        count: 3,
        severity: "danger",
        detail: "2 de seguridad, 1 de calidad",
        drilldownTo: "incidencias",
      },
      {
        id: "res-5",
        label: "Actividades bloqueadas",
        count: 2,
        severity: "danger",
        detail: "Falta liberación de plano A-105 Rev.08",
        drilldownTo: "programa",
      },
    ],
  },
  {
    projectId: "puerta-sierra",
    attention: [
      {
        id: "res-ps-1",
        label: "Reportes por revisar",
        count: 2,
        severity: "info",
        drilldownTo: "reportes",
      },
      {
        id: "res-ps-2",
        label: "Cantidades por validar",
        count: 5,
        severity: "warning",
        drilldownTo: "avance",
      },
      {
        id: "res-ps-3",
        label: "Gastos por revisar",
        count: 1,
        severity: "info",
        drilldownTo: "gastos",
      },
      {
        id: "res-ps-4",
        label: "Incidencias vencidas",
        count: 0,
        severity: "info",
        drilldownTo: "incidencias",
      },
      {
        id: "res-ps-5",
        label: "Actividades bloqueadas",
        count: 0,
        severity: "info",
        drilldownTo: "programa",
      },
    ],
  },
  {
    projectId: "corredor-norte",
    attention: [
      {
        id: "res-cn-1",
        label: "Reportes por revisar",
        count: 7,
        severity: "danger",
        drilldownTo: "reportes",
      },
      {
        id: "res-cn-2",
        label: "Cantidades por validar",
        count: 18,
        severity: "danger",
        drilldownTo: "avance",
      },
      {
        id: "res-cn-3",
        label: "Gastos por revisar",
        count: 9,
        severity: "warning",
        drilldownTo: "gastos",
      },
      {
        id: "res-cn-4",
        label: "Incidencias vencidas",
        count: 6,
        severity: "danger",
        drilldownTo: "incidencias",
      },
      {
        id: "res-cn-5",
        label: "Actividades bloqueadas",
        count: 4,
        severity: "danger",
        drilldownTo: "programa",
      },
    ],
  },
];

export function getDemoResidentSummary(projectId: string): ResidentSummary | undefined {
  return DEMO_RESIDENT_SUMMARIES.find((summary) => summary.projectId === projectId);
}

export const DEMO_MAESTRO_DAY: MaestroDay = {
  projectId: "maraluna",
  reportState: "returned",
  reportNote: "Devuelto por Residencia: falta evidencia fotográfica del colado en Nivel 5.",
  crewTotal: 14,
  crew: [
    { trade: "Albañiles", count: 6 },
    { trade: "Ayudantes", count: 5 },
    { trade: "Fierreros", count: 3 },
  ],
  tasks: [
    {
      id: "t-1",
      concept: "Colado de losa",
      location: "Torre B · Nivel 5 · Eje 3–7",
      targetQuantity: "120 m²",
    },
    {
      id: "t-2",
      concept: "Armado de muros",
      location: "Torre B · Nivel 6 · Zona norte",
      targetQuantity: "45 m²",
    },
    {
      id: "t-3",
      concept: "Limpieza y habilitado",
      location: "Patio de maniobras",
      targetQuantity: "Jornada",
    },
  ],
  issues: [
    {
      id: "i-1",
      title: "Falta barandal provisional en Nivel 5",
      location: "Torre B · Nivel 5",
      dueDate: "Hoy",
      overdue: true,
    },
    {
      id: "i-2",
      title: "Revisar cimbra dañada en eje 6",
      location: "Torre B · Nivel 4",
      dueDate: "Mañana",
      overdue: false,
    },
  ],
  drawings: [
    {
      id: "d-1",
      code: "A-105",
      revision: "Rev.08",
      title: "Planta arquitectónica Nivel 5",
      publishedAt: "Hace 2 días",
      isCurrent: true,
    },
    {
      id: "d-2",
      code: "E-210",
      revision: "Rev.03",
      title: "Armado de losa Torre B",
      publishedAt: "Hace 1 semana",
      isCurrent: true,
    },
  ],
};

export const DEMO_ACCOUNTING_ATTENTION: AttentionItem[] = [
  {
    id: "con-1",
    label: "Gastos sin factura",
    count: 23,
    severity: "danger",
    detail: "Demo · $412,380 sin comprobante fiscal",
  },
  {
    id: "con-2",
    label: "Reembolsos pendientes",
    count: 8,
    severity: "warning",
    detail: "Demo · $96,540 por pagar a personal",
  },
  {
    id: "con-3",
    label: "Facturas con problema",
    count: 4,
    severity: "danger",
    detail: "XML inválido o datos fiscales incorrectos",
  },
  {
    id: "con-4",
    label: "Documentación pendiente",
    count: 12,
    severity: "info",
    detail: "Comprobantes de pago y contratos de proveedor",
  },
];

export const DEMO_ACCOUNTING_ROWS: AccountingRow[] = [
  {
    id: "a-1",
    projectId: "maraluna",
    provider: "Aceros del Pacífico",
    concept: "Varilla 3/8 · 4 ton",
    amount: 148900,
    date: "2026-08-21",
    paymentStatus: "pending",
    invoiceStatus: "problem",
  },
  {
    id: "a-2",
    projectId: "corredor-norte",
    provider: "Arrendadora Bahía",
    concept: "Renta de retroexcavadora",
    amount: 86400,
    date: "2026-08-19",
    paymentStatus: "partial",
    invoiceStatus: "pending",
  },
  {
    id: "a-3",
    projectId: "puerta-sierra",
    provider: "Ferretería El Roble",
    concept: "Consumibles de obra",
    amount: 12750,
    date: "2026-08-18",
    paymentStatus: "paid",
    invoiceStatus: "validated",
  },
  {
    id: "a-4",
    projectId: "maraluna",
    provider: "Concretos Sinaloa",
    concept: "Concreto f'c=250 · 32 m³",
    amount: 204800,
    date: "2026-08-16",
    paymentStatus: "pending",
    invoiceStatus: "received",
  },
  {
    id: "a-5",
    projectId: "corredor-norte",
    provider: "Transportes Zaragoza",
    concept: "Acarreo de material",
    amount: 39600,
    date: "2026-08-15",
    paymentStatus: "pending",
    invoiceStatus: "pending",
  },
];
