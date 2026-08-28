import { ChevronRight } from "lucide-react";
import { AppLink } from "@/components/common/AppLink";
import { EmptyState } from "@/components/common/States";
import { cn } from "@/lib/utils";
import type { AttentionItem as AttentionItemType, AttentionSeverity } from "@/types/domain";

const SEVERITY: Record<AttentionSeverity, { dot: string; label: string; count: string }> = {
  info: { dot: "bg-info", label: "Informativo", count: "text-foreground" },
  warning: { dot: "bg-warning", label: "Atención", count: "text-warning" },
  danger: { dot: "bg-danger", label: "Urgente", count: "text-danger" },
};

export function AttentionItem({
  item,
  params,
}: {
  item: AttentionItemType;
  params?: Record<string, string> | undefined;
}) {
  const severity = SEVERITY[item.severity];

  const content = (
    <>
      <span className="flex min-w-0 items-start gap-3">
        <span aria-hidden className={cn("mt-1.5 h-2 w-2 shrink-0 rounded-full", severity.dot)} />
        <span className="min-w-0">
          <span className="block text-sm font-medium">{item.label}</span>
          <span className="block text-xs text-muted-foreground">
            {severity.label}
            {item.detail ? ` · ${item.detail}` : ""}
          </span>
        </span>
      </span>
      <span className="flex shrink-0 items-center gap-2">
        <span className={cn("tabular text-xl font-semibold", severity.count)}>{item.count}</span>
        {item.drilldownTo ? <ChevronRight aria-hidden className="h-4 w-4 text-muted-foreground" /> : null}
      </span>
    </>
  );

  const className =
    "flex min-h-14 w-full items-center justify-between gap-3 border-b border-border px-4 py-3 text-left last:border-b-0";

  if (!item.drilldownTo) {
    return <li className={className}>{content}</li>;
  }

  return (
    <li className="border-b border-border last:border-b-0">
      <AppLink
        to={item.drilldownTo}
        params={params}
        className={cn(className, "border-b-0 hover:bg-muted")}
        aria-label={`${item.label}: ${item.count}`}
      >
        {content}
      </AppLink>
    </li>
  );
}

interface AttentionPanelProps {
  items: AttentionItemType[];
  title?: string | undefined;
  params?: Record<string, string> | undefined;
  emptyTitle?: string | undefined;
}

/** "Requiere tu atención": bloque operativo principal para Director, Residente y Contabilidad. */
export function AttentionPanel({
  items,
  title = "Requiere tu atención",
  params,
  emptyTitle = "Nada requiere tu atención",
}: AttentionPanelProps) {
  const pending = items.filter((item) => item.count > 0);

  return (
    <section aria-labelledby="attention-heading">
      <div className="mb-3 flex items-baseline justify-between">
        <h2 id="attention-heading" className="text-sm font-semibold">
          {title}
        </h2>
        <span className="text-xs text-muted-foreground">{pending.length} pendientes</span>
      </div>
      {pending.length === 0 ? (
        <EmptyState title={emptyTitle} description="No hay pendientes registrados por ahora." />
      ) : (
        <ul className="panel overflow-hidden">
          {pending.map((item) => (
            <AttentionItem key={item.id} item={item} params={params} />
          ))}
        </ul>
      )}
    </section>
  );
}
