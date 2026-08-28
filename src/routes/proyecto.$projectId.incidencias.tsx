import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/incidencias")({
  head: () => ({
    meta: [
      { title: "Incidencias | DFN Control" },
      { name: "description", content: "Registro y seguimiento de incidencias de obra con responsable, fecha compromiso, evidencia y ubicación en plano." },
    ],
  }),
  component: IncidenciasPage,
});

function IncidenciasPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Incidencias" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Incidencias"
        description="Registro y seguimiento de incidencias de obra con responsable, fecha compromiso, evidencia y ubicación en plano."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
