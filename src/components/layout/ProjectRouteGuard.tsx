/**
 * Guard de UX para rutas de proyecto.
 *
 * Si la URL apunta a un proyecto que no está en authorizationContext.projects,
 * no se renderiza nada del proyecto y se redirige a un destino seguro.
 * No revela si el proyecto existe. Defensa en profundidad de UX únicamente:
 * la autoridad real sigue siendo RLS en la base de datos.
 */
import { useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import type { ReactNode } from "react";
import { LoadingState } from "@/components/common/States";
import { hasPortfolioAccess } from "@/config/navigation";
import { useAuth } from "@/contexts/auth-context";
import { useProjectContext } from "@/contexts/project-context";

export function ProjectRouteGuard({ children }: { children: ReactNode }) {
  const { authorizationContext } = useAuth();
  const { activeProject, isUnauthorizedProjectUrl, selectableProjects } = useProjectContext();
  const navigate = useNavigate();

  useEffect(() => {
    if (!authorizationContext || !isUnauthorizedProjectUrl) return;

    if (hasPortfolioAccess(authorizationContext)) {
      void navigate({ to: "/portafolio", replace: true });
      return;
    }
    const fallback = selectableProjects[0];
    if (fallback) {
      void navigate({
        to: "/proyecto/$projectId",
        params: { projectId: fallback.id },
        replace: true,
      });
      return;
    }
    void navigate({ to: "/perfil", replace: true });
  }, [authorizationContext, isUnauthorizedProjectUrl, selectableProjects, navigate]);

  if (!activeProject) {
    return <LoadingState rows={3} />;
  }

  return <>{children}</>;
}
