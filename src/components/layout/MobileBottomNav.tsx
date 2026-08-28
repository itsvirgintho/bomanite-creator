import { AppLink } from "@/components/common/AppLink";
import { getNavItems, MOBILE_NAV_LIMIT } from "@/config/navigation";
import { useProjectContext } from "@/contexts/project-context";
import { useSession } from "@/contexts/session-context";

/** Navegación inferior móvil: máximo 5 destinos, objetivos táctiles amplios. */
export function MobileBottomNav() {
  const { user, role } = useSession();
  const { activeProject } = useProjectContext();

  const items = getNavItems({
    role,
    financialLevel: user.financialLevel,
    hasProject: Boolean(activeProject),
    surface: "mobile",
  }).slice(0, MOBILE_NAV_LIMIT);

  const params = activeProject ? { projectId: activeProject.id } : undefined;

  return (
    <nav
      aria-label="Navegación inferior"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-card pb-[env(safe-area-inset-bottom)] lg:hidden"
    >
      <ul className="flex">
        {items.map((item) => (
          <li key={item.id} className="flex-1">
            <AppLink
              to={item.to}
              params={params}
              activeOptions={{ exact: item.to === "/proyecto/$projectId" }}
              className="flex min-h-14 flex-col items-center justify-center gap-1 px-1 py-2 text-[0.6875rem] text-muted-foreground data-[status=active]:font-semibold data-[status=active]:text-foreground"
            >
              <item.icon aria-hidden className="h-5 w-5" />
              <span className="truncate">{item.shortLabel ?? item.label}</span>
            </AppLink>
          </li>
        ))}
      </ul>
    </nav>
  );
}
