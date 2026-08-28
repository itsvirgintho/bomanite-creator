import { createFileRoute, Link } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import { AttentionPanel } from "@/components/attention/AttentionPanel";
import { HealthIndicator } from "@/components/common/HealthIndicator";
import { MetricGrid } from "@/components/common/MetricTile";
import { PageHeader, SectionHeader } from "@/components/common/PageHeader";
import { ProgressCompare } from "@/components/common/ProgressCompare";
import { DemoDataNotice } from "@/components/demo/DemoDataNotice";
import { AppShell } from "@/components/layout/AppShell";
import { DEMO_DIRECTOR_ATTENTION, DEMO_PROJECTS } from "@/mocks";
import { formatCurrency } from "@/lib/format";
import type { MetricValue } from "@/types/domain";

export const Route = createFileRoute("/portafolio")({
  head: () => ({
    meta: [
      { title: "Portafolio | DFN Control" },
      { name: "description", content: "Control ejecutivo del portafolio de proyectos DFN." },
    ],
  }),
  component: PortafolioPage,
});

function PortafolioPage() {
  const totalContract = DEMO_PROJECTS.reduce((sum, p) => sum + p.contractAmount, 0);
  const totalEstimated = DEMO_PROJECTS.reduce((sum, p) => sum + p.estimatedAmount, 0);
  const totalCollected = DEMO_PROJECTS.reduce((sum, p) => sum + p.collectedAmount, 0);
  const totalInvoiced = DEMO_PROJECTS.reduce((sum, p) => sum + p.invoicedAmount, 0);
  const plannedAvg = DEMO_PROJECTS.reduce((s, p) => s + p.plannedProgress, 0) / DEMO_PROJECTS.length;
  const actualAvg = DEMO_PROJECTS.reduce((s, p) => s + p.actualProgress, 0) / DEMO_PROJECTS.length;

  const metrics: MetricValue[] = [
    { id: "m-1", label: "Proyectos activos", value: String(DEMO_PROJECTS.length), hint: "Portafolio autorizado" },
    {
      id: "m-2",
      label: "Avance programado",
      value: `${plannedAvg.toFixed(1)}%`,
      hint: "Promedio ponderado demo",
    },
    {
      id: "m-3",
      label: "Avance real",
      value: `${actualAvg.toFixed(1)}%`,
      emphasis: actualAvg >= plannedAvg ? "success" : "warning",
      hint: `Desviación ${(actualAvg - plannedAvg).toFixed(1)} pts`,
    },
    { id: "m-4", label: "Contratado", value: formatCurrency(totalContract, { compact: true }) },
    { id: "m-5", label: "Estimado", value: formatCurrency(totalEstimated, { compact: true }) },
    {
      id: "m-6",
      label: "Por cobrar",
      value: formatCurrency(totalInvoiced - totalCollected, { compact: true }),
      emphasis: "warning",
      hint: "Facturado no cobrado",
    },
  ];

  return (
    <AppShell contextLabel="Portafolio DFN">
      <div className="space-y-6">
        <PageHeader
          title="Portafolio"
          overline="Dirección General"
          subtitle="Estado ejecutivo de los proyectos y pendientes que requieren decisión."
          actions={<DemoDataNotice />}
        />

        <AttentionPanel items={DEMO_DIRECTOR_ATTENTION} />

        <section>
          <SectionHeader title="Indicadores del portafolio" hint="Valores de demostración" />
          <MetricGrid metrics={metrics} />
        </section>

        <section>
          <SectionHeader title="Proyectos" hint="Selecciona un proyecto para ver su detalle" />
          <ul className="space-y-3">
            {DEMO_PROJECTS.map((project) => (
              <li key={project.id}>
                <Link
                  to="/proyecto/$projectId"
                  params={{ projectId: project.id }}
                  className="panel flex flex-col gap-4 p-4 transition-colors hover:border-border-strong lg:flex-row lg:items-center"
                >
                  <div className="min-w-0 lg:w-72">
                    <div className="flex items-center gap-2">
                      <span className="overline">{project.code}</span>
                      <HealthIndicator health={project.health} />
                    </div>
                    <p className="mt-1 truncate text-base font-semibold">{project.name}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {project.client} · {project.location}
                    </p>
                  </div>

                  <div className="flex-1">
                    <ProgressCompare planned={project.plannedProgress} actual={project.actualProgress} />
                  </div>

                  <dl className="grid grid-cols-3 gap-4 lg:w-96">
                    <div>
                      <dt className="overline">Contrato</dt>
                      <dd className="tabular text-sm font-medium">
                        {formatCurrency(project.contractAmount, { compact: true })}
                      </dd>
                    </div>
                    <div>
                      <dt className="overline">Cobrado</dt>
                      <dd className="tabular text-sm font-medium">
                        {formatCurrency(project.collectedAmount, { compact: true })}
                      </dd>
                    </div>
                    <div>
                      <dt className="overline">Días restantes</dt>
                      <dd className="tabular text-sm font-medium">{project.remainingDays}</dd>
                    </div>
                  </dl>

                  <ChevronRight aria-hidden className="hidden h-5 w-5 text-muted-foreground lg:block" />
                </Link>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </AppShell>
  );
}
