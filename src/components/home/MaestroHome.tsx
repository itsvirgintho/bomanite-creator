import { Camera, ClipboardList, Receipt, TriangleAlert } from "lucide-react";
import { AppLink } from "@/components/common/AppLink";
import { QuickActionGrid, type QuickAction } from "@/components/common/QuickActionGrid";
import { StatusPill, type StatusTone } from "@/components/common/StatusPill";
import { EmptyState } from "@/components/common/States";
import { DemoDataNotice } from "@/components/demo/DemoDataNotice";
import { DEMO_MAESTRO_DAY } from "@/mocks";
import type { DailyReportState, Project } from "@/types/domain";

const REPORT_STATE: Record<DailyReportState, { label: string; tone: StatusTone }> = {
  none: { label: "Sin reporte de hoy", tone: "warning" },
  draft: { label: "Reporte en borrador", tone: "warning" },
  submitted: { label: "Reporte enviado", tone: "info" },
  returned: { label: "Reporte devuelto", tone: "danger" },
  approved: { label: "Reporte aprobado", tone: "success" },
};

/**
 * Home del Maestro de Obra: móvil primero, sin tablas y sin información financiera sensible.
 * No se muestran contrato, precios unitarios, margen ni cobranza.
 */
export function MaestroHome({ project }: { project: Project }) {
  const day = DEMO_MAESTRO_DAY;
  const report = REPORT_STATE[day.reportState];

  const actions: QuickAction[] = [
    { id: "a-report", label: "Reporte diario", icon: ClipboardList, to: "/proyecto/$projectId/reportes", params: { projectId: project.id } },
    { id: "a-photo", label: "Foto", icon: Camera, to: "/proyecto/$projectId/reportes", params: { projectId: project.id } },
    { id: "a-expense", label: "Gasto", icon: Receipt, to: "/proyecto/$projectId/gastos", params: { projectId: project.id } },
    { id: "a-issue", label: "Incidencia", icon: TriangleAlert, to: "/proyecto/$projectId/incidencias", params: { projectId: project.id } },
  ];

  return (
    <div className="mx-auto max-w-2xl space-y-5">
      <header>
        <p className="overline">Tu obra</p>
        <h1 className="text-2xl font-semibold">{project.name}</h1>
        <p className="text-sm text-muted-foreground">{project.location}</p>
        <DemoDataNotice className="mt-3" />
      </header>

      <section
        aria-labelledby="reporte-heading"
        className="rounded-lg border-2 border-border-strong bg-card p-4"
      >
        <h2 id="reporte-heading" className="sr-only">
          Estado del reporte
        </h2>
        <StatusPill tone={report.tone}>{report.label}</StatusPill>
        {day.reportNote ? <p className="mt-2 text-sm">{day.reportNote}</p> : null}
        <AppLink
          to="/proyecto/$projectId/reportes"
          params={{ projectId: project.id }}
          className="mt-3 flex min-h-12 items-center justify-center rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground"
        >
          Abrir reporte diario
        </AppLink>
      </section>

      <section aria-labelledby="hoy-heading">
        <h2 id="hoy-heading" className="mb-2 text-sm font-semibold">
          Trabajo de hoy
        </h2>
        {day.tasks.length === 0 ? (
          <EmptyState title="Sin actividades asignadas hoy" />
        ) : (
          <ul className="space-y-2">
            {day.tasks.map((task) => (
              <li key={task.id} className="panel p-4">
                <p className="text-base font-semibold">{task.concept}</p>
                <p className="text-sm text-muted-foreground">{task.location}</p>
                <p className="mt-1 text-sm font-medium">Meta: {task.targetQuantity}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="cuadrilla-heading" className="panel p-4">
        <h2 id="cuadrilla-heading" className="text-sm font-semibold">
          Tu cuadrilla
        </h2>
        <p className="tabular mt-1 text-3xl font-semibold">{day.crewTotal}</p>
        <ul className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted-foreground">
          {day.crew.map((member) => (
            <li key={member.trade}>
              {member.trade}: <span className="tabular font-medium text-foreground">{member.count}</span>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="incidencias-heading">
        <h2 id="incidencias-heading" className="mb-2 text-sm font-semibold">
          Incidencias asignadas
        </h2>
        {day.issues.length === 0 ? (
          <EmptyState title="No tienes incidencias asignadas" />
        ) : (
          <ul className="space-y-2">
            {day.issues.map((issue) => (
              <li key={issue.id} className="panel p-4">
                <div className="flex items-start justify-between gap-3">
                  <p className="text-sm font-medium">{issue.title}</p>
                  <StatusPill tone={issue.overdue ? "danger" : "info"}>
                    {issue.overdue ? "Vencida" : issue.dueDate}
                  </StatusPill>
                </div>
                <p className="mt-1 text-xs text-muted-foreground">{issue.location}</p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="planos-heading">
        <h2 id="planos-heading" className="mb-2 text-sm font-semibold">
          Planos vigentes
        </h2>
        <ul className="space-y-2">
          {day.drawings.map((drawing) => (
            <li key={drawing.id} className="panel flex items-center justify-between gap-3 p-4">
              <div className="min-w-0">
                <p className="text-sm font-semibold">
                  {drawing.code} · {drawing.revision}
                </p>
                <p className="truncate text-xs text-muted-foreground">
                  {drawing.title} · {drawing.publishedAt}
                </p>
              </div>
              {drawing.isCurrent ? <StatusPill tone="success">Vigente</StatusPill> : null}
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="acciones-heading">
        <h2 id="acciones-heading" className="mb-2 text-sm font-semibold">
          Acciones rápidas
        </h2>
        <QuickActionGrid actions={actions} />
      </section>
    </div>
  );
}
