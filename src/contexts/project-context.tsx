/**
 * ProjectContext — el proyecto activo es canónicamente la URL (/proyecto/$projectId).
 * localStorage se usa SOLO en cliente, tras hidratar, para recordar el último proyecto.
 */
import { useParams } from "@tanstack/react-router";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { getDemoProject } from "@/mocks";
import { useSession } from "@/contexts/session-context";
import type { Project } from "@/types/domain";

const LAST_PROJECT_KEY = "dfn.demo.last-project";

interface ProjectContextValue {
  /** Proyecto activo derivado de la URL. Puede ser undefined (Director / Contabilidad). */
  activeProject: Project | undefined;
  /** Último proyecto recordado en el navegador (solo tras hidratar). */
  lastProjectId: string | undefined;
  /** Proyectos que el usuario demo puede seleccionar. */
  selectableProjects: Project[];
}

const ProjectContext = createContext<ProjectContextValue | null>(null);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const params = useParams({ strict: false });
  const { availableProjects } = useSession();
  const [lastProjectId, setLastProjectId] = useState<string | undefined>(undefined);

  const projectId = typeof params.projectId === "string" ? params.projectId : undefined;
  const urlProject = getDemoProject(projectId);
  const activeProject =
    urlProject && availableProjects.some((project) => project.id === urlProject.id) ? urlProject : undefined;

  useEffect(() => {
    setLastProjectId(window.localStorage.getItem(LAST_PROJECT_KEY) ?? undefined);
  }, []);

  useEffect(() => {
    if (activeProject) {
      window.localStorage.setItem(LAST_PROJECT_KEY, activeProject.id);
      setLastProjectId(activeProject.id);
    }
  }, [activeProject]);

  const value = useMemo<ProjectContextValue>(
    () => ({ activeProject, lastProjectId, selectableProjects: availableProjects }),
    [activeProject, lastProjectId, availableProjects],
  );

  return <ProjectContext.Provider value={value}>{children}</ProjectContext.Provider>;
}

export function useProjectContext(): ProjectContextValue {
  const context = useContext(ProjectContext);
  if (!context) throw new Error("useProjectContext debe usarse dentro de ProjectProvider");
  return context;
}
