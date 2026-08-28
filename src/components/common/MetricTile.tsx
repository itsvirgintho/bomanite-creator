import { Link } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";
import type { MetricValue } from "@/types/domain";

const EMPHASIS: Record<NonNullable<MetricValue["emphasis"]>, string> = {
  neutral: "text-foreground",
  success: "text-success",
  warning: "text-warning",
  danger: "text-danger",
};

/**
 * Toda métrica importante debe poder llevar a su origen (drilldownTo).
 * En esta fase el destino puede ser un módulo en preparación.
 */
export function MetricTile({ metric }: { metric: MetricValue }) {
  const body = (
    <>
      <span className="overline">{metric.label}</span>
      <span
        className={cn(
          "tabular mt-2 block text-2xl font-semibold",
          EMPHASIS[metric.emphasis ?? "neutral"],
        )}
      >
        {metric.value}
      </span>
      {metric.hint ? (
        <span className="mt-1 block text-xs text-muted-foreground">{metric.hint}</span>
      ) : null}
    </>
  );

  if (metric.drilldownTo) {
    return (
      <Link
        to={metric.drilldownTo}
        className="panel group relative block p-4 transition-colors hover:border-border-strong"
      >
        {body}
        <ChevronRight
          aria-hidden
          className="absolute top-4 right-3 h-4 w-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100"
        />
      </Link>
    );
  }

  return <div className="panel p-4">{body}</div>;
}

export function MetricGrid({ metrics }: { metrics: MetricValue[] }) {
  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-6">
      {metrics.map((metric) => (
        <MetricTile key={metric.id} metric={metric} />
      ))}
    </div>
  );
}
