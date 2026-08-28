import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/estimaciones")({
  head: () => ({
    meta: [
      { title: "Estimaciones | DFN Control" },
      { name: "description", content: "Generación y control de estimaciones al cliente, con resguardo de cantidades, precios y montos aprobados." },
    ],
  }),
  component: EstimacionesPage,
});

function EstimacionesPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Estimaciones" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Estimaciones"
        description="Generación y control de estimaciones al cliente, con resguardo de cantidades, precios y montos aprobados."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
