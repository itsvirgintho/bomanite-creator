import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/programa")({
  head: () => ({
    meta: [
      { title: "Programa de obra | DFN Control" },
      { name: "description", content: "Programa con línea base, pronóstico y fechas reales, dependencias entre actividades y motivos de bloqueo." },
    ],
  }),
  component: ProgramaPage,
});

function ProgramaPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Programa de obra" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Programa de obra"
        description="Programa con línea base, pronóstico y fechas reales, dependencias entre actividades y motivos de bloqueo."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
