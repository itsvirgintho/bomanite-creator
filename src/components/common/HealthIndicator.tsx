import { StatusPill, type StatusTone } from "@/components/common/StatusPill";
import type { ProjectHealth } from "@/types/domain";

const HEALTH: Record<ProjectHealth, { label: string; tone: StatusTone; symbol: string }> = {
  on_plan: { label: "En programa", tone: "success", symbol: "●" },
  at_risk: { label: "En riesgo", tone: "warning", symbol: "▲" },
  critical: { label: "Crítico", tone: "danger", symbol: "■" },
};

/** El estado nunca depende solo del color: incluye símbolo y etiqueta textual. */
export function HealthIndicator({ health }: { health: ProjectHealth }) {
  const config = HEALTH[health];
  return (
    <StatusPill tone={config.tone} icon={<span aria-hidden>{config.symbol}</span>}>
      {config.label}
    </StatusPill>
  );
}

export function healthLabel(health: ProjectHealth): string {
  return HEALTH[health].label;
}
