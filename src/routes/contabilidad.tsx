import { createFileRoute } from "@tanstack/react-router";
import { AttentionPanel } from "@/components/attention/AttentionPanel";
import { MetricGrid } from "@/components/common/MetricTile";
import { PageHeader, SectionHeader } from "@/components/common/PageHeader";
import { StatusPill, type StatusTone } from "@/components/common/StatusPill";
import { DemoDataNotice } from "@/components/demo/DemoDataNotice";
import { AppShell } from "@/components/layout/AppShell";
import { DEMO_ACCOUNTING_ATTENTION, DEMO_ACCOUNTING_ROWS, getDemoProject } from "@/mocks";
import { formatCurrency, formatDate } from "@/lib/format";
import type { InvoiceStatus, MetricValue, PaymentStatus } from "@/types/domain";

export const Route = createFileRoute("/contabilidad")({
  head: () => ({
    meta: [
      { title: "Contabilidad | DFN Control" },
      { name: "description", content: "Control financiero y documental de todos los proyectos." },
    ],
  }),
  component: ContabilidadPage,
});

const PAYMENT: Record<PaymentStatus, { label: string; tone: StatusTone }> = {
  not_required: { label: "No aplica", tone: "neutral" },
  pending: { label: "Pago pendiente", tone: "warning" },
  partial: { label: "Pago parcial", tone: "info" },
  paid: { label: "Pagado", tone: "success" },
};

const INVOICE: Record<InvoiceStatus, { label: string; tone: StatusTone }> = {
  not_required: { label: "No aplica", tone: "neutral" },
  pending: { label: "Factura pendiente", tone: "warning" },
  requested: { label: "Factura solicitada", tone: "info" },
  received: { label: "Factura recibida", tone: "info" },
  problem: { label: "Factura con problema", tone: "danger" },
  validated: { label: "Factura validada", tone: "success" },
};

const FILTERS = [
  { id: "proyecto", label: "Proyecto" },
  { id: "periodo", label: "Periodo" },
  { id: "proveedor", label: "Proveedor" },
  { id: "pago", label: "Estado de pago" },
  { id: "factura", label: "Estado de factura" },
];

function ContabilidadPage() {
  const pendingAmount = DEMO_ACCOUNTING_ROWS.filter((row) => row.paymentStatus !== "paid").reduce(
    (sum, row) => sum + row.amount,
    0,
  );

  const metrics: MetricValue[] = [
    { id: "c-1", label: "Documentos en revisión", value: String(DEMO_ACCOUNTING_ROWS.length) },
    { id: "c-2", label: "Importe por pagar", value: formatCurrency(pendingAmount, { compact: true }), emphasis: "warning" },
    { id: "c-3", label: "Facturas con problema", value: "4", emphasis: "danger" },
    { id: "c-4", label: "Reembolsos pendientes", value: "8", emphasis: "warning" },
    { id: "c-5", label: "Proveedores activos", value: "27" },
    { id: "c-6", label: "Periodo", value: "Agosto 2026", hint: "Filtro por definir" },
  ];

  return (
    <AppShell contextLabel="Contabilidad · todos los proyectos">
      <div className="space-y-6">
        <PageHeader
          title="Contabilidad"
          overline="Vista global"
          subtitle="Trabajo financiero y documental de todos los proyectos autorizados."
          actions={<DemoDataNotice />}
        />

        <AttentionPanel items={DEMO_ACCOUNTING_ATTENTION} />

        <section>
          <SectionHeader title="Resumen del periodo" hint="Valores de demostración" />
          <MetricGrid metrics={metrics} />
        </section>

        <section>
          <SectionHeader title="Documentos" hint="Los filtros se habilitarán en una fase posterior" />
          <div className="mb-3 flex flex-wrap gap-2" aria-label="Filtros en preparación">
            {FILTERS.map((filter) => (
              <button
                key={filter.id}
                type="button"
                disabled
                className="min-h-9 cursor-not-allowed rounded-md border border-dashed border-border-strong px-3 text-xs text-muted-foreground"
              >
                {filter.label}
              </button>
            ))}
          </div>

          {/* Escritorio: tabla densa */}
          <div className="panel hidden overflow-x-auto lg:block">
            <table className="w-full text-sm">
              <caption className="sr-only">Documentos financieros de demostración</caption>
              <thead>
                <tr className="border-b border-border text-left">
                  <th scope="col" className="overline px-4 py-2">Proveedor</th>
                  <th scope="col" className="overline px-4 py-2">Concepto</th>
                  <th scope="col" className="overline px-4 py-2">Proyecto</th>
                  <th scope="col" className="overline px-4 py-2">Fecha</th>
                  <th scope="col" className="overline px-4 py-2 text-right">Importe</th>
                  <th scope="col" className="overline px-4 py-2">Pago</th>
                  <th scope="col" className="overline px-4 py-2">Factura</th>
                </tr>
              </thead>
              <tbody>
                {DEMO_ACCOUNTING_ROWS.map((row) => (
                  <tr key={row.id} className="border-b border-border last:border-b-0">
                    <td className="px-4 py-3 font-medium">{row.provider}</td>
                    <td className="px-4 py-3 text-muted-foreground">{row.concept}</td>
                    <td className="px-4 py-3">{getDemoProject(row.projectId)?.name ?? "—"}</td>
                    <td className="px-4 py-3 text-muted-foreground">{formatDate(row.date)}</td>
                    <td className="tabular px-4 py-3 text-right">{formatCurrency(row.amount)}</td>
                    <td className="px-4 py-3">
                      <StatusPill tone={PAYMENT[row.paymentStatus].tone}>
                        {PAYMENT[row.paymentStatus].label}
                      </StatusPill>
                    </td>
                    <td className="px-4 py-3">
                      <StatusPill tone={INVOICE[row.invoiceStatus].tone}>
                        {INVOICE[row.invoiceStatus].label}
                      </StatusPill>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Móvil: tarjetas */}
          <ul className="space-y-3 lg:hidden">
            {DEMO_ACCOUNTING_ROWS.map((row) => (
              <li key={row.id} className="panel p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{row.provider}</p>
                    <p className="truncate text-xs text-muted-foreground">{row.concept}</p>
                  </div>
                  <p className="tabular text-sm font-semibold">{formatCurrency(row.amount)}</p>
                </div>
                <p className="mt-2 text-xs text-muted-foreground">
                  {getDemoProject(row.projectId)?.name} · {formatDate(row.date)}
                </p>
                <div className="mt-3 flex flex-wrap gap-2">
                  <StatusPill tone={PAYMENT[row.paymentStatus].tone}>
                    {PAYMENT[row.paymentStatus].label}
                  </StatusPill>
                  <StatusPill tone={INVOICE[row.invoiceStatus].tone}>
                    {INVOICE[row.invoiceStatus].label}
                  </StatusPill>
                </div>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </AppShell>
  );
}
