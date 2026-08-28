import { createFileRoute, Outlet } from "@tanstack/react-router";
import { AppShell } from "@/components/layout/AppShell";
import { ProjectRouteGuard } from "@/components/layout/ProjectRouteGuard";
import { useProjectContext } from "@/contexts/project-context";

export const Route = createFileRoute("/proyecto/$projectId")({
  head: () => ({
    meta: [
      { title: "Proyecto | DFN Control" },
      { name: "description", content: "Control operativo del proyecto en DFN Control." },
    ],
  }),
  component: ProjectLayout,
});

/** Layout de proyecto: el proyecto activo proviene canónicamente de la URL. */
function ProjectLayout() {
  const { activeProject } = useProjectContext();

  return (
    <AppShell contextLabel={activeProject?.name}>
      <ProjectRouteGuard>
        <Outlet />
      </ProjectRouteGuard>
    </AppShell>
  );
}
