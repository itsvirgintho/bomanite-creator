import { AttentionPanel } from "@/components/attention/AttentionPanel";
import { HealthIndicator } from "@/components/common/HealthIndicator";
import { MetricGrid } from "@/components/common/MetricTile";
import { PageHeader, SectionHeader } from "@/components/common/PageHeader";
import { ProgressCompare } from "@/components/common/ProgressCompare";
import { DemoDataNotice } from "@/components/demo/DemoDataNotice";
import { getDemoResidentSummary } from "@/mocks";
import type { MetricValue, Project } from "@/types/domain";

/** Home operativo del Residente: "Requiere tu atención" primero. */
export function ResidentHome({ project }: { project: Project }) {
  const summary = getDemoResidentSummary(project.id);
  const deviation = project.actualProgress - project.plannedProgress;

  const metrics: MetricValue[] = [
    {
      id: "r-1",
      label: "Avance programado",
      value: `${project.plannedProgress.toFixed(1)}%`,
      drilldownTo: "/proyecto/$projectId/programa",
    },
    {
      id: "r-2",
      label: "Avance real",
      value: `${project.actualProgress.toFixed(1)}%`,
      emphasis: deviation >= 0 ? "success" : "warning",
      drilldownTo: "/proyecto/$projectId/avance",
    },
    {
      id: "r-3",
      label: "Desviación",
      value: `${deviation >= 0 ? "+" : ""}${deviation.toFixed(1)} pts`,
      emphasis: deviation >= 0 ? "success" : deviation > -5 ? "warning" : "danger",
      drilldownTo: "/proyecto/$projectId/avance",
    },
    { id: "r-4", label: "Días transcurridos", value: String(project.elapsedDays) },
    {
      id: "r-5",
      label: "Días restantes",
      value: String(project.remainingDays),
      emphasis: project.remainingDays < 45 ? "warning" : "neutral",
    },
    {
      id: "r-6",
      label: "Personal en obra",
      value: String(project.workforceOnSite),
      hint: "Registro de hoy",
      drilldownTo: "/proyecto/$projectId/reportes",
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title={project.name}
        overline={`${project.code} · Residencia de obra`}
        subtitle={`${project.client} · ${project.location}`}
        actions={
          <div className="flex items-center gap-2">
            <HealthIndicator health={project.health} />
            <DemoDataNotice />
          </div>
        }
      />

      <AttentionPanel items={summary?.attention ?? []} params={{ projectId: project.id }} />

      <section>
        <SectionHeader title="Estado del proyecto" hint="Valores de demostración" />
        <MetricGrid metrics={metrics} params={{ projectId: project.id }} />
      </section>

      <section>
        <SectionHeader title="Avance programado vs real" />
        <div className="panel p-5">
          <ProgressCompare planned={project.plannedProgress} actual={project.actualProgress} />
        </div>
      </section>
    </div>
  );
}
