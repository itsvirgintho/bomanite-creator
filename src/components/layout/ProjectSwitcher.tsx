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
import { GLOBAL_ROLES } from "@/config/roles";
import { useProjectContext } from "@/contexts/project-context";
import { useSession } from "@/contexts/session-context";
import { cn } from "@/lib/utils";

interface ProjectSwitcherProps {
  tone?: "light" | "dark";
  className?: string;
}

/**
 * El proyecto activo es canónicamente la URL. Este control solo navega.
 * Maestro nunca ve proyectos fuera de su asignación demo.
 */
export function ProjectSwitcher({ tone = "dark", className }: ProjectSwitcherProps) {
  const { activeProject, selectableProjects } = useProjectContext();
  const { demoRole } = useSession();
  const navigate = useNavigate();
  const canWorkGlobally = GLOBAL_ROLES.includes(demoRole);
  const singleProject = selectableProjects.length <= 1 && !canWorkGlobally;

  const label = activeProject ? activeProject.name : canWorkGlobally ? "Todos los proyectos" : "Sin proyecto";
  const sublabel = activeProject ? activeProject.code : "Vista global";

  if (singleProject) {
    return (
      <div
        className={cn(
          "flex items-center gap-2 rounded-md border px-3 py-2 text-left",
          tone === "light"
            ? "border-sidebar-border bg-sidebar-accent text-sidebar-accent-foreground"
            : "border-border bg-card",
          className,
        )}
      >
        <span className="min-w-0 flex-1">
          <span className="block truncate text-sm font-medium">{label}</span>
          <span className="block truncate text-xs opacity-70">{sublabel} · proyecto asignado</span>
        </span>
        <Lock aria-hidden className="h-3.5 w-3.5 opacity-60" />
      </div>
    );
  }

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
        <DropdownMenuLabel>Proyectos disponibles</DropdownMenuLabel>
        {selectableProjects.map((project) => (
          <DropdownMenuItem
            key={project.id}
            onSelect={() => void navigate({ to: "/proyecto/$projectId", params: { projectId: project.id } })}
          >
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm">{project.name}</span>
              <span className="block truncate text-xs text-muted-foreground">
                {project.code} · {project.location}
              </span>
            </span>
            {activeProject?.id === project.id ? <Check aria-hidden className="h-4 w-4" /> : null}
          </DropdownMenuItem>
        ))}
        {canWorkGlobally ? (
          <>
            <DropdownMenuSeparator />
            {demoRole === "contabilidad" ? (
              <DropdownMenuItem onSelect={() => void navigate({ to: "/contabilidad" })}>
                Vista global de contabilidad
              </DropdownMenuItem>
            ) : (
              <DropdownMenuItem onSelect={() => void navigate({ to: "/portafolio" })}>
                Vista de portafolio
              </DropdownMenuItem>
            )}
          </>
        ) : null}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
