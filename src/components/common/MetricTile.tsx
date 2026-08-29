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
  params?: Record<string, string> | undefined;
  featured?: boolean | undefined;
}

/**
 * Toda métrica importante debe poder llevar a su origen (drilldownTo).
 * En esta fase el destino puede ser un módulo en preparación.
 * La primera métrica del grid se presenta como tile destacada (bento).
 */
export function MetricTile({ metric, params, featured = false }: MetricTileProps) {
  const body = (
    <>
      <span className="overline">{metric.label}</span>
      <span
        className={cn(
          "tabular mt-2 block font-display font-semibold",
          featured ? "text-4xl" : "text-2xl",
          EMPHASIS[metric.emphasis ?? "neutral"],
        )}
      >
        {metric.value}
      </span>
      {metric.hint ? <span className="mt-1 block text-xs text-muted-foreground">{metric.hint}</span> : null}
    </>
  );

  const tileClass = cn(
    "panel group relative p-4",
    featured && "panel-ember flex flex-col justify-end p-5",
  );

  if (metric.drilldownTo) {
    return (
      <AppLink
        to={metric.drilldownTo}
        params={params}
        className={cn(
          tileClass,
          "block transition-all hover:border-border-strong",
          featured && "hover:shadow-raised",
        )}
      >
        {body}
        <ChevronRight
          aria-hidden
          className="absolute top-4 right-3 h-4 w-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100"
        />
      </AppLink>
    );
  }

  return <div className={tileClass}>{body}</div>;
}

export function MetricGrid({
  metrics,
  params,
  className,
}: {
  metrics: MetricValue[];
  params?: Record<string, string> | undefined;
  className?: string | undefined;
}) {
  return (
    <div className={cn("grid grid-cols-2 gap-3 lg:grid-cols-4", className)}>
      {metrics.map((metric, index) => (
        <div key={metric.id} className={cn(index === 0 && "col-span-2 row-span-2")}>
          <div className="h-full [&>*]:h-full">
            <MetricTile metric={metric} params={params} featured={index === 0} />
          </div>
        </div>
      ))}
    </div>
  );
}
