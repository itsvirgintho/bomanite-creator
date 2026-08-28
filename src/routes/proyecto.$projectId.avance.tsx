import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/avance")({
  head: () => ({
    meta: [
      { title: "Avance físico | DFN Control" },
      { name: "description", content: "Registro de cantidades reportadas y validadas por concepto y ubicación, con evidencia y trazabilidad al reporte de origen." },
    ],
  }),
  component: AvancePage,
});

function AvancePage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Avance físico" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Avance físico"
        description="Registro de cantidades reportadas y validadas por concepto y ubicación, con evidencia y trazabilidad al reporte de origen."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
