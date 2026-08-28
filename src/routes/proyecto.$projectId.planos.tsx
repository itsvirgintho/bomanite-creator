import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/planos")({
  head: () => ({
    meta: [
      { title: "Planos | DFN Control" },
      { name: "description", content: "Consulta de planos por revisión vigente, historial de revisiones y marcadores de evidencia sobre el plano." },
    ],
  }),
  component: PlanosPage,
});

function PlanosPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Planos" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Planos"
        description="Consulta de planos por revisión vigente, historial de revisiones y marcadores de evidencia sobre el plano."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
