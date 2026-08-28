import { FlaskConical } from "lucide-react";
import { DEMO_DATA_LABEL } from "@/mocks";
import { cn } from "@/lib/utils";

/** Indicador discreto pero visible: toda vista con datos mock debe mostrarlo. */
export function DemoDataNotice({ className }: { className?: string }) {
  return (
    <p
      className={cn(
        "inline-flex items-center gap-1.5 rounded-sm border border-dashed border-border-strong bg-muted px-2 py-1 text-xs text-muted-foreground",
        className,
      )}
    >
      <FlaskConical aria-hidden className="h-3.5 w-3.5" />
      {DEMO_DATA_LABEL}
    </p>
  );
}
