import { Link, useNavigate } from "@tanstack/react-router";
import { UserRound } from "lucide-react";
import { useEffect } from "react";
import type { ReactNode } from "react";
import { Brand } from "@/components/common/Brand";
import { RoleBadge } from "@/components/common/RoleBadge";
import { LoadingState } from "@/components/common/States";
import { MobileBottomNav } from "@/components/layout/MobileBottomNav";
import { ProjectSwitcher } from "@/components/layout/ProjectSwitcher";
import { SidebarNav } from "@/components/layout/SidebarNav";
import { useProjectContext } from "@/contexts/project-context";
import { useSession } from "@/contexts/session-context";

interface AppShellProps {
  children: ReactNode;
  /** Contexto mostrado en la barra superior (nombre del proyecto o ámbito). */
  contextLabel?: string | undefined;
}

export function AppShell({ children, contextLabel }: AppShellProps) {
  const { user, role, isSignedIn, hydrated } = useSession();
  const { activeProject } = useProjectContext();
  const navigate = useNavigate();

  useEffect(() => {
    if (hydrated && !isSignedIn) {
      void navigate({ to: "/auth", replace: true });
    }
  }, [hydrated, isSignedIn, navigate]);

  if (!hydrated || !isSignedIn) {
    return (
      <div className="mx-auto max-w-3xl p-6">
        <LoadingState rows={2} />
      </div>
    );
  }

  const label = contextLabel ?? activeProject?.name ?? "Vista global";

  return (
    <div className="flex min-h-screen bg-background">
      <aside className="sticky top-0 hidden h-screen lg:block">
        <SidebarNav />
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Encabezado móvil compacto */}
        <header className="sticky top-0 z-30 border-b border-border bg-card px-4 py-2 lg:hidden">
          <div className="flex items-center justify-between gap-3">
            <Link to="/" aria-label="Ir al inicio">
              <Brand size="sm" />
            </Link>
            <Link
              to="/perfil"
              aria-label="Abrir perfil"
              className="inline-flex h-11 w-11 items-center justify-center rounded-md border border-border"
            >
              <UserRound aria-hidden className="h-5 w-5" />
            </Link>
          </div>
          <div className="mt-2">
            <ProjectSwitcher />
          </div>
        </header>

        {/* Barra contextual de escritorio */}
        <header className="sticky top-0 z-30 hidden border-b border-border bg-card px-6 py-3 lg:block">
          <div className="flex items-center justify-between gap-4">
            <div className="min-w-0">
              <p className="overline">Contexto actual</p>
              <p className="truncate text-sm font-medium">{label}</p>
            </div>
            <div className="flex items-center gap-3">
              <RoleBadge role={role} />
              <Link
                to="/perfil"
                className="inline-flex items-center gap-2 rounded-md border border-border px-3 py-1.5 text-sm hover:border-border-strong"
              >
                <UserRound aria-hidden className="h-4 w-4" />
                {user.name}
              </Link>
            </div>
          </div>
        </header>

        <main className="min-w-0 flex-1 px-4 pt-4 pb-24 lg:px-6 lg:pt-6 lg:pb-10">{children}</main>
      </div>

      <MobileBottomNav />
    </div>
  );
}
