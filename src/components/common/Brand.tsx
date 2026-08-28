import { cn } from "@/lib/utils";

/**
 * Marca temporal centralizada. Sustituir aquí cuando existan assets definitivos.
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
        "inline-flex items-center gap-2 font-semibold tracking-[0.14em] uppercase",
        tone === "light" ? "text-sidebar-foreground" : "text-foreground",
        size === "sm" && "text-xs",
        size === "md" && "text-sm",
        size === "lg" && "text-base",
        className,
      )}
    >
      <span
        aria-hidden
        className={cn(
          "inline-block rounded-xs bg-accent",
          size === "lg" ? "h-5 w-1.5" : "h-4 w-1",
        )}
      />
      {BRAND_NAME}
    </span>
  );
}
