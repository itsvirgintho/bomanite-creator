import { Link } from "@tanstack/react-router";
import { AppLink } from "@/components/common/AppLink";
import { Brand } from "@/components/common/Brand";
import { ProjectSwitcher } from "@/components/layout/ProjectSwitcher";
import { getNavItems, type NavItem } from "@/config/navigation";
import { useAuth } from "@/contexts/auth-context";
import { useProjectContext } from "@/contexts/project-context";
import { useSession } from "@/contexts/session-context";
import { profileDisplayName, roleDisplayLabel } from "@/types/authorization";

const GROUP_LABELS: Record<NavItem["group"], string> = {
  principal: "Principal",
  operacion: "Operación",
  control: "Control",
  cuenta: "Cuenta",
};

const GROUP_ORDER: NavItem["group"][] = ["principal", "operacion", "control", "cuenta"];

/** Sidebar de escritorio. UI visibility only — NOT authorization. */
export function SidebarNav() {
  const { user, demoRole } = useSession();
  const { activeProject } = useProjectContext();
  const { authorizationContext } = useAuth();

  const items = getNavItems({
    role: demoRole,
    financialLevel: user.financialLevel,
    hasProject: Boolean(activeProject),
    surface: "desktop",
  });

  const params = activeProject ? { projectId: activeProject.id } : undefined;

  return (
    <nav
      aria-label="Navegación principal"
      className="flex h-full w-60 shrink-0 flex-col bg-sidebar text-sidebar-foreground"
    >
      <div className="border-b border-sidebar-border px-4 py-4">
        <Link to="/" aria-label="Ir al inicio">
          <Brand tone="light" />
        </Link>
      </div>

      <div className="border-b border-sidebar-border p-3">
        <ProjectSwitcher tone="light" />
      </div>

      <div className="flex-1 overflow-y-auto px-2 py-3">
        {GROUP_ORDER.map((group) => {
          const groupItems = items.filter((item) => item.group === group);
          if (groupItems.length === 0) return null;
          return (
            <div key={group} className="mb-4">
              <p className="px-2 pb-1.5 text-[0.6875rem] font-semibold tracking-[0.08em] text-sidebar-foreground/50 uppercase">
                {GROUP_LABELS[group]}
              </p>
              <ul className="space-y-0.5">
                {groupItems.map((item) => (
                  <li key={item.id}>
                    <AppLink
                      to={item.to}
                      params={params}
                      activeOptions={{ exact: item.to === "/proyecto/$projectId" }}
                      className="flex items-center gap-2.5 rounded-md px-2 py-2 text-sm text-sidebar-foreground/85 hover:bg-sidebar-accent hover:text-sidebar-accent-foreground data-[status=active]:bg-sidebar-accent data-[status=active]:font-medium data-[status=active]:text-sidebar-accent-foreground"
                    >
                      <item.icon aria-hidden className="h-4 w-4 shrink-0" />
                      {item.label}
                    </AppLink>
                  </li>
                ))}
              </ul>
            </div>
          );
        })}
      </div>

      <div className="border-t border-sidebar-border px-4 py-3">
        <p className="truncate text-sm font-medium">
          {profileDisplayName(authorizationContext?.profile)}
        </p>
        {roleDisplayLabel(authorizationContext, activeProject?.id) ? (
          <p className="truncate text-xs text-sidebar-foreground/60">
            {roleDisplayLabel(authorizationContext, activeProject?.id)}
          </p>
        ) : null}
      </div>
    </nav>
  );
}
