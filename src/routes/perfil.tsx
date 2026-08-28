import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AppShell } from "@/components/layout/AppShell";
import { PageHeader } from "@/components/common/PageHeader";
import { useAuth } from "@/contexts/auth-context";
import { profileDisplayName } from "@/types/authorization";

export const Route = createFileRoute("/perfil")({
  head: () => ({
    meta: [
      { title: "Perfil | DFN Control" },
      { name: "description", content: "Perfil del usuario autenticado en DFN Control." },
    ],
  }),
  component: PerfilPage,
});

function PerfilPage() {
  const { user, authorizationContext, logout } = useAuth();
  const navigate = useNavigate();

  const profile = authorizationContext?.profile ?? null;
  const organizations = authorizationContext?.organizations ?? [];
  const projects = authorizationContext?.projects ?? [];

  return (
    <AppShell contextLabel="Perfil">
      <div className="mx-auto max-w-3xl space-y-6">
        <PageHeader title="Perfil" subtitle="Datos de la sesión actual." overline="Cuenta" />

        <section className="panel p-5">
          <dl className="grid gap-4 sm:grid-cols-2">
            <div>
              <dt className="overline">Usuario</dt>
              <dd className="mt-1 text-sm font-medium">{profileDisplayName(profile)}</dd>
            </div>
            <div>
              <dt className="overline">Correo</dt>
              <dd className="mt-1 text-sm">{user?.email ?? "—"}</dd>
            </div>
            <div>
              <dt className="overline">Puesto</dt>
              <dd className="mt-1 text-sm">{profile?.job_title ?? "—"}</dd>
            </div>
            <div>
              <dt className="overline">Código de empleado</dt>
              <dd className="mt-1 text-sm">{profile?.employee_code ?? "—"}</dd>
            </div>
            <div>
              <dt className="overline">Organizaciones</dt>
              <dd className="mt-1 text-sm">
                {organizations.length > 0
                  ? organizations.map((organization) => organization.name).join(", ")
                  : "Sin organizaciones asignadas"}
              </dd>
            </div>
            <div>
              <dt className="overline">Proyectos con acceso</dt>
              <dd className="mt-1 text-sm">
                {projects.length > 0
                  ? projects.map((project) => project.name).join(", ")
                  : "Sin proyectos asignados"}
              </dd>
            </div>
            {authorizationContext?.is_superadmin ? (
              <div className="sm:col-span-2">
                <dt className="overline">Plataforma</dt>
                <dd className="mt-1 text-sm">
                  Cuenta de Superadministrador de plataforma. No implica acceso a organizaciones,
                  proyectos ni información financiera.
                </dd>
              </div>
            ) : null}
          </dl>
        </section>

        <button
          type="button"
          onClick={() => {
            void (async () => {
              await logout();
              void navigate({ to: "/auth", replace: true });
            })();
          }}
          className="min-h-11 w-full rounded-md border border-border-strong px-4 text-sm font-medium hover:bg-muted sm:w-auto"
        >
          Cerrar sesión
        </button>
      </div>
    </AppShell>
  );
}
