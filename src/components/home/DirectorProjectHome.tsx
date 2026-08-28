import { AttentionPanel } from "@/components/attention/AttentionPanel";
import { HealthIndicator } from "@/components/common/HealthIndicator";
import { MetricGrid } from "@/components/common/MetricTile";
import { PageHeader, SectionHeader } from "@/components/common/PageHeader";
import { ProgressCompare } from "@/components/common/ProgressCompare";
import { DemoDataNotice } from "@/components/demo/DemoDataNotice";
import { getDemoResidentSummary } from "@/mocks";
import { formatCurrency } from "@/lib/format";
import type { MetricValue, Project } from "@/types/domain";

/** Drill-down del Director dentro de un proyecto del portafolio. */
export function DirectorProjectHome({ project }: { project: Project }) {
  const summary = getDemoResidentSummary(project.id);
  const deviation = project.actualProgress - project.plannedProgress;

  const metrics: MetricValue[] = [
    {
      id: "d-1",
      label: "Desviación",
      value: `${deviation >= 0 ? "+" : ""}${deviation.toFixed(1)} pts`,
      emphasis: deviation >= 0 ? "success" : deviation > -5 ? "warning" : "danger",
      drilldownTo: "/proyecto/$projectId/avance",
    },
    { id: "d-2", label: "Días restantes", value: String(project.remainingDays) },
    { id: "d-3", label: "Contrato", value: formatCurrency(project.contractAmount, { compact: true }) },
    {
      id: "d-4",
      label: "Estimado",
      value: formatCurrency(project.estimatedAmount, { compact: true }),
      drilldownTo: "/proyecto/$projectId/estimaciones",
    },
    { id: "d-5", label: "Facturado", value: formatCurrency(project.invoicedAmount, { compact: true }) },
    {
      id: "d-6",
      label: "Por cobrar",
      value: formatCurrency(project.invoicedAmount - project.collectedAmount, { compact: true }),
      emphasis: "warning",
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title={project.name}
        overline={`${project.code} · Dirección General`}
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
        <SectionHeader title="Control ejecutivo" hint="Valores de demostración" />
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
