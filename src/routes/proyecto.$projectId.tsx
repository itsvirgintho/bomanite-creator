import { createFileRoute, Link, Outlet } from "@tanstack/react-router";
import { EmptyState } from "@/components/common/States";
import { AppShell } from "@/components/layout/AppShell";
import { useProjectContext } from "@/contexts/project-context";
import { getDemoProject } from "@/mocks";

export const Route = createFileRoute("/proyecto/$projectId")({
  head: ({ params }) => {
    const project = getDemoProject(params.projectId);
    const title = project ? `${project.name} | DFN Control` : "Proyecto | DFN Control";
    return {
      meta: [
        { title },
        { name: "description", content: "Control operativo del proyecto en DFN Control." },
      ],
    };
  },
  component: ProjectLayout,
});

/** Layout de proyecto: el proyecto activo proviene canónicamente de la URL. */
function ProjectLayout() {
  const { activeProject } = useProjectContext();

  return (
    <AppShell contextLabel={activeProject?.name}>
      {activeProject ? (
        <Outlet />
      ) : (
        <EmptyState
          title="Proyecto no disponible"
          description="El proyecto no existe o no está asignado a tu usuario."
          action={
            <Link to="/" className="text-sm font-medium underline underline-offset-4">
              Ir a mi inicio
            </Link>
          }
        />
      )}
    </AppShell>
  );
}
