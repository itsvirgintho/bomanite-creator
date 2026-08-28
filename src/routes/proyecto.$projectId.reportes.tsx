import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/reportes")({
  head: () => ({
    meta: [
      { title: "Reportes diarios | DFN Control" },
      { name: "description", content: "Captura, revisión y aprobación de reportes diarios de obra con cuadrilla, actividades, cantidades, fotos e incidencias." },
    ],
  }),
  component: ReportesPage,
});

function ReportesPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Reportes diarios" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Reportes diarios"
        description="Captura, revisión y aprobación de reportes diarios de obra con cuadrilla, actividades, cantidades, fotos e incidencias."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
