import { Link } from "@tanstack/react-router";
import { Construction, Inbox, RefreshCw, TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function EmptyState({
  title,
  description,
  action,
  icon,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: ReactNode;
}) {
  return (
    <div className="panel flex flex-col items-center gap-2 px-6 py-10 text-center">
      <span className="text-muted-foreground" aria-hidden>
        {icon ?? <Inbox className="h-6 w-6" />}
      </span>
      <p className="text-sm font-medium">{title}</p>
      {description ? <p className="max-w-sm text-sm text-muted-foreground">{description}</p> : null}
      {action}
    </div>
  );
}

/** Skeletons con la forma del contenido; nunca spinners de página completa. */
export function LoadingState({ rows = 3, className }: { rows?: number; className?: string }) {
  return (
    <div className={cn("space-y-3", className)} role="status" aria-label="Cargando contenido">
      {Array.from({ length: rows }).map((_, index) => (
        <div key={index} className="panel space-y-2 p-4">
          <div className="h-3 w-24 animate-pulse rounded-sm bg-muted" />
          <div className="h-5 w-40 animate-pulse rounded-sm bg-muted" />
          <div className="h-3 w-full animate-pulse rounded-sm bg-muted" />
        </div>
      ))}
    </div>
  );
}

export function ErrorState({
  title = "No pudimos mostrar esta información",
  description = "Vuelve a intentarlo en unos momentos. Si el problema continúa, avisa a Sistemas.",
  onRetry,
}: {
  title?: string;
  description?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="panel flex flex-col items-center gap-3 px-6 py-10 text-center">
      <TriangleAlert aria-hidden className="h-6 w-6 text-danger" />
      <div>
        <p className="text-sm font-medium">{title}</p>
        <p className="mt-1 max-w-sm text-sm text-muted-foreground">{description}</p>
      </div>
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="inline-flex min-h-11 items-center gap-2 rounded-md border border-border-strong px-4 text-sm font-medium hover:bg-muted"
        >
          <RefreshCw aria-hidden className="h-4 w-4" />
          Reintentar
        </button>
      ) : null}
    </div>
  );
}

export function ModulePlaceholder({
  moduleName,
  description,
  backTo,
}: {
  moduleName: string;
  description: string;
  backTo?: ReactNode;
}) {
  return (
    <div className="panel flex flex-col items-start gap-3 p-6">
      <span className="inline-flex items-center gap-2 rounded-full border border-border bg-muted px-3 py-1 text-xs font-medium text-muted-foreground">
        <Construction aria-hidden className="h-3.5 w-3.5" />
        Módulo en preparación
      </span>
      <div>
        <h2 className="text-lg font-semibold">{moduleName}</h2>
        <p className="mt-1 max-w-xl text-sm text-muted-foreground">{description}</p>
      </div>
      <p className="text-xs text-muted-foreground">
        Esta sección aún no tiene funcionalidad. Se habilitará en una fase posterior.
      </p>
      {backTo}
    </div>
  );
}

export function BackToProjectLink({ projectId }: { projectId: string }) {
  return (
    <Link
      to="/proyecto/$projectId"
      params={{ projectId }}
      className="text-sm font-medium text-foreground underline underline-offset-4"
    >
      Volver al resumen del proyecto
    </Link>
  );
}
