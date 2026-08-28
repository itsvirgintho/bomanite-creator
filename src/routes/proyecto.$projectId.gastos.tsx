import { createFileRoute } from "@tanstack/react-router";
import { BackToProjectLink, ModulePlaceholder } from "@/components/common/States";
import { PageHeader } from "@/components/common/PageHeader";

export const Route = createFileRoute("/proyecto/$projectId/gastos")({
  head: () => ({
    meta: [
      { title: "Gastos | DFN Control" },
      { name: "description", content: "Comprobación de gastos con flujos independientes de aprobación, pago o reembolso y estado de factura." },
    ],
  }),
  component: GastosPage,
});

function GastosPage() {
  const { projectId } = Route.useParams();
  return (
    <div className="space-y-6">
      <PageHeader title="Gastos" overline="Proyecto" />
      <ModulePlaceholder
        moduleName="Gastos"
        description="Comprobación de gastos con flujos independientes de aprobación, pago o reembolso y estado de factura."
        backTo={<BackToProjectLink projectId={projectId} />}
      />
    </div>
  );
}
