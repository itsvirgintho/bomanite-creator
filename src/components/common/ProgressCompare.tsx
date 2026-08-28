import { cn } from "@/lib/utils";

interface ProgressCompareProps {
  planned: number;
  actual: number;
  compact?: boolean;
  className?: string;
}

/** Avance programado vs real. La desviación se comunica con texto y signo, no solo color. */
export function ProgressCompare({ planned, actual, compact = false, className }: ProgressCompareProps) {
  const deviation = actual - planned;
  const tone = deviation >= 0 ? "text-success" : deviation > -5 ? "text-warning" : "text-danger";

  return (
    <div className={cn("w-full", className)}>
      {!compact ? (
        <div className="mb-1.5 flex items-baseline justify-between text-xs text-muted-foreground">
          <span>
            Programado <span className="tabular text-foreground">{planned.toFixed(1)}%</span>
          </span>
          <span>
            Real <span className="tabular text-foreground">{actual.toFixed(1)}%</span>
          </span>
        </div>
      ) : null}
      <div
        className="relative h-2 w-full overflow-hidden rounded-full bg-muted"
        role="img"
        aria-label={`Avance real ${actual.toFixed(1)} por ciento, programado ${planned.toFixed(1)} por ciento`}
      >
        <div className="h-full rounded-full bg-primary" style={{ width: `${Math.min(actual, 100)}%` }} />
        <div
          aria-hidden
          className="absolute top-0 h-full w-0.5 bg-foreground"
          style={{ left: `${Math.min(planned, 100)}%` }}
        />
      </div>
      <p className={cn("tabular mt-1.5 text-xs font-medium", tone)}>
        Desviación {deviation >= 0 ? "+" : ""}
        {deviation.toFixed(1)} pts
      </p>
    </div>
  );
}
