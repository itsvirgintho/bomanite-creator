import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AppShell } from "@/components/layout/AppShell";
import { PageHeader } from "@/components/common/PageHeader";
import { RoleBadge } from "@/components/common/RoleBadge";
import { DemoRoleSwitcher } from "@/components/demo/DemoRoleSwitcher";
import { ROLE_LABELS } from "@/config/roles";
import { useSession } from "@/contexts/session-context";
import { DEMO_PROJECTS } from "@/mocks";

export const Route = createFileRoute("/perfil")({
  head: () => ({
    meta: [
      { title: "Perfil | DFN Control" },
      { name: "description", content: "Perfil del usuario y controles de demostración." },
    ],
  }),
  component: PerfilPage,
});

function PerfilPage() {
  const { user, role, availableProjects, signOut } = useSession();
  const navigate = useNavigate();

  const scope =
    user.assignedProjectIds.length === 0
      ? `Acceso a los ${DEMO_PROJECTS.length} proyectos del portafolio`
      : availableProjects.map((project) => project.name).join(", ");

  return (
    <AppShell contextLabel="Perfil">
      <div className="mx-auto max-w-3xl space-y-6">
        <PageHeader title="Perfil" subtitle="Datos de la sesión actual." overline="Cuenta" />

        <section className="panel p-5">
          <dl className="grid gap-4 sm:grid-cols-2">
            <div>
              <dt className="overline">Usuario</dt>
              <dd className="mt-1 text-sm font-medium">{user.name}</dd>
            </div>
            <div>
              <dt className="overline">Correo</dt>
              <dd className="mt-1 text-sm">{user.email}</dd>
            </div>
            <div>
              <dt className="overline">Rol</dt>
              <dd className="mt-1 flex items-center gap-2 text-sm">
                <RoleBadge role={role} />
                <span className="text-muted-foreground">{ROLE_LABELS[role]}</span>
              </dd>
            </div>
            <div>
              <dt className="overline">Nivel financiero</dt>
              <dd className="mt-1 text-sm">F{user.financialLevel}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="overline">Proyectos asignados</dt>
              <dd className="mt-1 text-sm">{scope}</dd>
            </div>
          </dl>
        </section>

        {/* DEMO/DEV ONLY — remover al implementar Supabase Auth */}
        <DemoRoleSwitcher />

        <button
          type="button"
          onClick={() => {
            signOut();
            void navigate({ to: "/auth", replace: true });
          }}
          className="min-h-11 w-full rounded-md border border-border-strong px-4 text-sm font-medium hover:bg-muted sm:w-auto"
        >
          Cerrar sesión
        </button>
      </div>
    </AppShell>
  );
}
