import { createFileRoute } from "@tanstack/react-router";
import { DirectorProjectHome } from "@/components/home/DirectorProjectHome";
import { MaestroHome } from "@/components/home/MaestroHome";
import { ResidentHome } from "@/components/home/ResidentHome";
import { EmptyState, LoadingState } from "@/components/common/States";
import { useProjectContext } from "@/contexts/project-context";
import { useSession } from "@/contexts/session-context";

export const Route = createFileRoute("/proyecto/$projectId/")({
  component: ProjectHome,
});

/** Home dentro del proyecto, adaptado al rol activo. */
function ProjectHome() {
  const { activeProject } = useProjectContext();
  const { role, hydrated } = useSession();

  if (!hydrated) return <LoadingState rows={3} />;
  if (!activeProject) return <EmptyState title="Proyecto no disponible" />;

  switch (role) {
    case "maestro":
      return <MaestroHome project={activeProject} />;
    case "director_general":
      return <DirectorProjectHome project={activeProject} />;
    default:
      return <ResidentHome project={activeProject} />;
  }
}
