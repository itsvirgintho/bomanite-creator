/**
 * DFN Control — domain types (Foundation Phase 1).
 * Technical naming in English; UI copy in Spanish.
 * No backend yet: these types describe the shape future Supabase data will take.
 */

export type Role = "director_general" | "residente" | "maestro" | "contabilidad";

/** F0 none · F1 own expenses · F2 project costs · F3 contract/prices · F4 executive */
export type FinancialLevel = 0 | 1 | 2 | 3 | 4;

export type ProjectHealth = "on_plan" | "at_risk" | "critical";

export type AttentionSeverity = "info" | "warning" | "danger";

export interface Project {
  id: string;
  code: string;
  name: string;
  client: string;
  location: string;
  health: ProjectHealth;
  plannedProgress: number;
  actualProgress: number;
  startDate: string;
  endDate: string;
  elapsedDays: number;
  remainingDays: number;
  workforceOnSite: number;
  /** Financial values are demo-only and require financialLevel >= 3 to display. */
  contractAmount: number;
  estimatedAmount: number;
  invoicedAmount: number;
  collectedAmount: number;
}

export interface AttentionItem {
  id: string;
  label: string;
  count: number;
  severity: AttentionSeverity;
  detail?: string;
  /** Route this metric will eventually drill down into. */
  drilldownTo?: string;
}

export interface MetricValue {
  id: string;
  label: string;
  value: string;
  hint?: string;
  emphasis?: "neutral" | "success" | "warning" | "danger";
  drilldownTo?: string;
}

export interface CrewMember {
  trade: string;
  count: number;
}

export interface TodayTask {
  id: string;
  concept: string;
  location: string;
  targetQuantity: string;
}

export interface DrawingRef {
  id: string;
  code: string;
  revision: string;
  title: string;
  publishedAt: string;
  isCurrent: boolean;
}

export type DailyReportState = "none" | "draft" | "submitted" | "returned" | "approved";

export interface IssueRef {
  id: string;
  title: string;
  location: string;
  dueDate: string;
  overdue: boolean;
}

export interface MaestroDay {
  projectId: string;
  reportState: DailyReportState;
  reportNote?: string;
  crew: CrewMember[];
  crewTotal: number;
  tasks: TodayTask[];
  issues: IssueRef[];
  drawings: DrawingRef[];
}

export interface ResidentSummary {
  projectId: string;
  attention: AttentionItem[];
}

export type PaymentStatus = "not_required" | "pending" | "partial" | "paid";
export type InvoiceStatus = "not_required" | "pending" | "requested" | "received" | "problem" | "validated";

export interface AccountingRow {
  id: string;
  projectId: string;
  provider: string;
  concept: string;
  amount: number;
  date: string;
  paymentStatus: PaymentStatus;
  invoiceStatus: InvoiceStatus;
}

export interface DemoUser {
  id: string;
  name: string;
  email: string;
  role: Role;
  financialLevel: FinancialLevel;
  /** Empty array means access to every demo project (Director / Contabilidad). */
  assignedProjectIds: string[];
}
