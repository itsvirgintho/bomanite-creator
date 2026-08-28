import { useNavigate } from "@tanstack/react-router";
import { Check, ChevronsUpDown, Lock } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { hasAccountingAccess, hasPortfolioAccess } from "@/config/navigation";
import { useAuth } from "@/contexts/auth-context";
import { useProjectContext } from "@/contexts/project-context";
import { cn } from "@/lib/utils";

interface ProjectSwitcherProps {
  tone?: "light" | "dark";
  className?: string;
}

/**
 * El proyecto activo es canónicamente la URL. Este control solo navega.
 * Los proyectos y las vistas globales provienen del contexto real de
 * autorización. UI visibility only — NOT authorization.
 */
export function ProjectSwitcher({ tone = "dark", className }: ProjectSwitcherProps) {
  const { activeProject, selectableProjects } = useProjectContext();
  const { authorizationContext } = useAuth();
  const navigate = useNavigate();

  const canSeePortfolio = hasPortfolioAccess(authorizationContext);
  const canSeeAccounting = hasAccountingAccess(authorizationContext);
  const hasGlobalView = canSeePortfolio || canSeeAccounting;

  const staticContainerClass = cn(
    "flex items-center gap-2 rounded-md border px-3 py-2 text-left",
    tone === "light"
      ? "border-sidebar-border bg-sidebar-accent text-sidebar-accent-foreground"
      : "border-border bg-card",
    className,
  );

  // Sin proyectos ni ámbito global de negocio (p. ej. Superadmin puro).
  if (selectableProjects.length === 0 && !hasGlobalView) {
    return (
      <div className={staticContainerClass}>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium">Sin proyectos de negocio</span>
          <span className="block truncate text-xs opacity-70">Sin ámbito asignado</span>
        </span>
        <Lock aria-hidden className="h-3.5 w-3.5 opacity-60" />
      </div>
    );
  }

  // Un solo proyecto y sin ámbito global: presentación fija.
  if (selectableProjects.length === 1 && !hasGlobalView) {
    const only = selectableProjects[0]!;
    return (
      <div className={staticContainerClass}>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium">{only.name}</span>
          <span className="block truncate text-xs opacity-70">{only.code} · proyecto asignado</span>
        </span>
        <Lock aria-hidden className="h-3.5 w-3.5 opacity-60" />
      </div>
    );
  }

  const label = activeProject
    ? activeProject.name
    : canSeePortfolio
      ? "Todos los proyectos"
      : canSeeAccounting
        ? "Contabilidad global"
        : "Sin proyecto";
  const sublabel = activeProject ? activeProject.code : "Vista global";

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        aria-label="Cambiar de proyecto"
        className={cn(
          "flex min-h-11 w-full items-center gap-2 rounded-md border px-3 py-2 text-left",
          tone === "light"
            ? "border-sidebar-border bg-sidebar-accent text-sidebar-accent-foreground hover:brightness-110"
            : "border-border bg-card hover:border-border-strong",
          className,
        )}
      >
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium">{label}</span>
          <span className="block truncate text-xs opacity-70">{sublabel}</span>
        </span>
        <ChevronsUpDown aria-hidden className="h-4 w-4 opacity-70" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-64">
        {selectableProjects.length > 0 ? (
          <>
            <DropdownMenuLabel>Proyectos disponibles</DropdownMenuLabel>
            {selectableProjects.map((project) => (
              <DropdownMenuItem
                key={project.id}
                onSelect={() =>
                  void navigate({ to: "/proyecto/$projectId", params: { projectId: project.id } })
                }
              >
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm">{project.name}</span>
                  <span className="block truncate text-xs text-muted-foreground">
                    {project.code}
                    {project.location_label ? ` · ${project.location_label}` : ""}
                  </span>
                </span>
                {activeProject?.id === project.id ? <Check aria-hidden className="h-4 w-4" /> : null}
              </DropdownMenuItem>
            ))}
          </>
        ) : (
          <DropdownMenuLabel>Sin proyectos asignados</DropdownMenuLabel>
        )}

        {hasGlobalView ? (
          <>
            <DropdownMenuSeparator />
            {canSeePortfolio ? (
              <DropdownMenuItem onSelect={() => void navigate({ to: "/portafolio" })}>
                Vista de portafolio
              </DropdownMenuItem>
            ) : null}
            {canSeeAccounting ? (
              <DropdownMenuItem onSelect={() => void navigate({ to: "/contabilidad" })}>
                Vista global de contabilidad
              </DropdownMenuItem>
            ) : null}
          </>
        ) : null}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
