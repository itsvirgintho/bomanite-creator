import { cn } from "@/lib/utils";

/**
 * Marca centralizada. Sustituir aquí cuando existan assets definitivos.
 * No duplicar el wordmark en otros componentes.
 */
export const BRAND_NAME = "DFN CONTROL";
export const BRAND_SHORT = "DFN";

interface BrandProps {
  className?: string;
  tone?: "light" | "dark";
  size?: "sm" | "md" | "lg";
}

export function Brand({ className, tone = "dark", size = "md" }: BrandProps) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-2.5 font-display font-semibold tracking-[0.18em] uppercase",
        tone === "light" ? "text-sidebar-foreground" : "text-foreground",
        size === "sm" && "text-xs",
        size === "md" && "text-sm",
        size === "lg" && "text-lg",
        className,
      )}
    >
      <span
        aria-hidden
        className={cn(
          "inline-block rounded-xs bg-primary shadow-ember",
          size === "lg" ? "h-6 w-1.5" : "h-4 w-1",
        )}
      />
      {BRAND_NAME}
    </span>
  );
}
