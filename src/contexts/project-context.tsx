/**
 * ProjectContext — el proyecto activo es canónicamente la URL (/proyecto/$projectId).
 *
 * Los proyectos seleccionables provienen ÚNICAMENTE del contexto real de
 * autorización (public.get_my_authorization_context()). localStorage solo
 * recuerda el último proyecto y nunca se usa como autoridad: el id guardado
 * debe existir en authorizationContext.projects para considerarse válido.
 */
import { useParams } from "@tanstack/react-router";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useAuth } from "@/contexts/auth-context";
import type { AuthzProject } from "@/types/authorization";

const LAST_PROJECT_KEY = "dfn.last-project";

interface ProjectContextValue {
  /** Proyecto activo, resuelto desde la URL y validado contra el contexto real. */
  activeProject: AuthzProject | undefined;
  /** Id de proyecto presente en la URL (sin validar). */
  urlProjectId: string | undefined;
  /** true si la URL trae un proyecto que no está autorizado para el usuario. */
  isUnauthorizedProjectUrl: boolean;
  /** Último proyecto real recordado en el navegador (solo tras hidratar). */
  lastProjectId: string | undefined;
  /** Proyectos autorizados del usuario. */
  selectableProjects: AuthzProject[];
}

const ProjectContext = createContext<ProjectContextValue | null>(null);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const params = useParams({ strict: false });
  const { authorizationContext } = useAuth();
  const [rememberedProjectId, setRememberedProjectId] = useState<string | undefined>(undefined);

  const selectableProjects = useMemo(
    () => authorizationContext?.projects ?? [],
    [authorizationContext],
  );

  const urlProjectId = typeof params.projectId === "string" ? params.projectId : undefined;
  const activeProject = urlProjectId
    ? selectableProjects.find((project) => project.id === urlProjectId)
    : undefined;
  const isUnauthorizedProjectUrl = Boolean(urlProjectId) && !activeProject;

  useEffect(() => {
    setRememberedProjectId(window.localStorage.getItem(LAST_PROJECT_KEY) ?? undefined);
  }, []);

  useEffect(() => {
    if (activeProject) {
      window.localStorage.setItem(LAST_PROJECT_KEY, activeProject.id);
      setRememberedProjectId(activeProject.id);
    }
  }, [activeProject]);

  // El id recordado solo se expone si sigue autorizado.
  const lastProjectId = selectableProjects.some((project) => project.id === rememberedProjectId)
    ? rememberedProjectId
    : undefined;

  const value = useMemo<ProjectContextValue>(
    () => ({
      activeProject,
      urlProjectId,
      isUnauthorizedProjectUrl,
      lastProjectId,
      selectableProjects,
    }),
    [activeProject, urlProjectId, isUnauthorizedProjectUrl, lastProjectId, selectableProjects],
  );

  return <ProjectContext.Provider value={value}>{children}</ProjectContext.Provider>;
}

export function useProjectContext(): ProjectContextValue {
  const context = useContext(ProjectContext);
  if (!context) throw new Error("useProjectContext debe usarse dentro de ProjectProvider");
  return context;
}
