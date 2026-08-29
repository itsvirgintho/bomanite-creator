import { createFileRoute } from "@tanstack/react-router";
import { DirectorProjectHome } from "@/components/home/DirectorProjectHome";
import { MaestroHome } from "@/components/home/MaestroHome";
import { ResidentHome } from "@/components/home/ResidentHome";
import { EmptyState } from "@/components/common/States";
import { useProjectContext } from "@/contexts/project-context";
import { getDemoProject } from "@/mocks";

export const Route = createFileRoute("/proyecto/$projectId/")({
  component: ProjectHome,
});

/**
 * Home dentro del proyecto.
 * El contenido sigue siendo DEMO (Fase 1) y no se migra en este paso.
 * La variante mostrada depende del código de rol real solo como presentación:
 * no otorga ni infiere permisos.
 */
function ProjectHome() {
  const { activeProject } = useProjectContext();

  if (!activeProject) return null;

  // Solo se muestra contenido de demostración si coincide EXACTAMENTE con el id
  // del proyecto real activo. Nunca se sustituye por otro proyecto.
  const demoProject = getDemoProject(activeProject.id);
  if (!demoProject) {
    return (
      <EmptyState
        title={activeProject.name}
        description="Datos de demostración: el contenido de esta vista aún no está conectado."
      />
    );
  }

  const roleCode = activeProject.direct_membership?.role?.code ?? "";

  if (roleCode.startsWith("MAESTRO")) return <MaestroHome project={demoProject} />;
  if (roleCode.startsWith("DIRECTOR")) return <DirectorProjectHome project={demoProject} />;
  return <ResidentHome project={demoProject} />;
}
