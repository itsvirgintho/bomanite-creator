/**
 * SessionContext — capa de compatibilidad de UI.
 *
 * La AUTENTICACIÓN ya es real (Supabase Auth) y vive en `auth-context.tsx`.
 * Este contexto solo conserva datos de DEMO de la Fase 1 (proyectos mock y un rol
 * de UI heredado) que aún alimentan la navegación y las vistas no migradas.
 * El `demoRole` NO es el rol del usuario autenticado: jamás debe mostrarse como
 * identidad del usuario. El rol real se deriva de authorizationContext.
 * NO es autenticación y NO es autorización: la autoridad es RLS + el RPC
 * public.get_my_authorization_context().
 */
import { createContext, useContext, useMemo } from "react";
import type { ReactNode } from "react";
import { useAuth } from "@/contexts/auth-context";
import { DEMO_PROJECTS, DEMO_USERS } from "@/mocks";
import type { DemoUser, Project, Role } from "@/types/domain";

const DEFAULT_ROLE: Role = "director_general";

interface SessionContextValue {
  /** Identidad de UI (demo) para módulos aún no migrados. */
  user: DemoUser;
  /**
   * Rol de UI heredado de la Fase 1 (DEMO). No es el rol del usuario autenticado;
   * solo alimenta la navegación/vistas legacy. Nunca mostrarlo como identidad.
   */
  demoRole: Role;
  /** Sesión real de Supabase. */
  isSignedIn: boolean;
  /** Inicialización de la sesión real terminada. */
  hydrated: boolean;
  /** Proyectos mock visibles en la UI heredada. */
  availableProjects: Project[];
}

const SessionContext = createContext<SessionContextValue | null>(null);

export function SessionProvider({ children }: { children: ReactNode }) {
  const { session, initializing } = useAuth();

  const value = useMemo<SessionContextValue>(() => {
    const user = DEMO_USERS[DEFAULT_ROLE];
    const availableProjects =
      user.assignedProjectIds.length === 0
        ? DEMO_PROJECTS
        : DEMO_PROJECTS.filter((project) => user.assignedProjectIds.includes(project.id));
    return {
      user,
      demoRole: DEFAULT_ROLE,
      isSignedIn: Boolean(session),
      hydrated: !initializing,
      availableProjects,
    };
  }, [session, initializing]);

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionContextValue {
  const context = useContext(SessionContext);
  if (!context) throw new Error("useSession debe usarse dentro de SessionProvider");
  return context;
}
