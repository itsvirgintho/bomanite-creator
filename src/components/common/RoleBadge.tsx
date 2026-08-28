import { ROLE_LABELS } from "@/config/roles";
import { cn } from "@/lib/utils";
import type { Role } from "@/types/domain";

export function RoleBadge({ role, className }: { role: Role; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-sm border border-border bg-muted px-2 py-0.5 text-xs font-medium text-muted-foreground",
        className,
      )}
    >
      {ROLE_LABELS[role]}
    </span>
  );
}
