/**
 * DEMO/DEV ONLY — cambio de rol simulado para Foundation Phase 1.
 * NO es una capacidad de producción y NO es autorización.
 * Eliminar este componente y su uso en /perfil al implementar Supabase Auth
 * con membresía de proyecto, permisos y RLS.
 */
import { useNavigate } from "@tanstack/react-router";
import { ROLE_LABELS, ROLE_ORDER } from "@/config/roles";
import { getHomeRoute, useSession } from "@/contexts/session-context";
import { DEMO_USERS } from "@/mocks";
import { cn } from "@/lib/utils";
import type { Role } from "@/types/domain";

export function DemoRoleSwitcher() {
  const { role, setRole } = useSession();
  const navigate = useNavigate();

  function handleSelect(next: Role) {
    setRole(next);
    const home = getHomeRoute(DEMO_USERS[next]);
    void navigate({ to: home.to, params: home.params } as never);
  }

  return (
    <div className="rounded-lg border border-dashed border-border-strong bg-muted/60 p-4">
      <p className="overline">Controles DEMO/DEV</p>
      <h2 className="mt-1 text-sm font-semibold">Simulador de rol</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Solo para pruebas de la Fase 1. No representa permisos reales; la autorización se aplicará en
        Supabase con RLS.
      </p>
      <fieldset className="mt-3">
        <legend className="sr-only">Seleccionar rol de demostración</legend>
        <div className="grid gap-2 sm:grid-cols-2">
          {ROLE_ORDER.map((option) => {
            const selected = option === role;
            return (
              <button
                key={option}
                type="button"
                onClick={() => handleSelect(option)}
                aria-pressed={selected}
                className={cn(
                  "min-h-11 rounded-md border px-3 py-2 text-left text-sm font-medium transition-colors",
                  selected
                    ? "border-foreground bg-card"
                    : "border-border bg-card text-muted-foreground hover:border-border-strong",
                )}
              >
                <span className="block">{ROLE_LABELS[option]}</span>
                <span className="block text-xs font-normal text-muted-foreground">
                  {DEMO_USERS[option].name}
                  {selected ? " · activo" : ""}
                </span>
              </button>
            );
          })}
        </div>
      </fieldset>
    </div>
  );
}
