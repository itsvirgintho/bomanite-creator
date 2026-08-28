import type { ComponentType } from "react";
import { AppLink } from "@/components/common/AppLink";

export interface QuickAction {
  id: string;
  label: string;
  icon: ComponentType<{ className?: string }> | undefined;
  to: string;
  params?: Record<string, string> | undefined;
}

/** Acciones rápidas de campo: objetivos táctiles grandes, una acción por tarjeta. */
export function QuickActionGrid({ actions }: { actions: QuickAction[] }) {
  return (
    <div className="grid grid-cols-2 gap-3">
      {actions.map((action) => (
        <AppLink
          key={action.id}
          to={action.to}
          params={action.params}
          className="flex min-h-24 flex-col items-start justify-between rounded-lg border border-border-strong bg-card p-4 shadow-panel active:bg-muted"
        >
          <action.icon aria-hidden className="h-6 w-6 text-accent-foreground" />
          <span className="text-base font-semibold">{action.label}</span>
        </AppLink>
      ))}
    </div>
  );
}
