import { ChevronRight } from "lucide-react";
import { AppLink } from "@/components/common/AppLink";
import { cn } from "@/lib/utils";
import type { MetricValue } from "@/types/domain";

const EMPHASIS: Record<NonNullable<MetricValue["emphasis"]>, string> = {
  neutral: "text-foreground",
  success: "text-success",
  warning: "text-warning",
  danger: "text-danger",
};

interface MetricTileProps {
  metric: MetricValue;
  params?: Record<string, string>;
}

/**
 * Toda métrica importante debe poder llevar a su origen (drilldownTo).
 * En esta fase el destino puede ser un módulo en preparación.
 */
export function MetricTile({ metric, params }: MetricTileProps) {
  const body = (
    <>
      <span className="overline">{metric.label}</span>
      <span
        className={cn("tabular mt-2 block text-2xl font-semibold", EMPHASIS[metric.emphasis ?? "neutral"])}
      >
        {metric.value}
      </span>
      {metric.hint ? <span className="mt-1 block text-xs text-muted-foreground">{metric.hint}</span> : null}
    </>
  );

  if (metric.drilldownTo) {
    return (
      <AppLink
        to={metric.drilldownTo}
        params={params}
        className="panel group relative block p-4 transition-colors hover:border-border-strong"
      >
        {body}
        <ChevronRight
          aria-hidden
          className="absolute top-4 right-3 h-4 w-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100"
        />
      </AppLink>
    );
  }

  return <div className="panel p-4">{body}</div>;
}

export function MetricGrid({
  metrics,
  params,
  className,
}: {
  metrics: MetricValue[];
  params?: Record<string, string>;
  className?: string;
}) {
  return (
    <div className={cn("grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-6", className)}>
      {metrics.map((metric) => (
        <MetricTile key={metric.id} metric={metric} params={params} />
      ))}
    </div>
  );
}
