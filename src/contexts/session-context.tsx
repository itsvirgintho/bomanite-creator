/**
 * DEMO SESSION — Foundation Phase 1.
 * Sesión simulada en memoria. NO es autenticación real.
 * Se reemplazará íntegramente por Supabase Auth + membresía de proyecto.
 * UI visibility only — NOT authorization.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { DEMO_PROJECTS, DEMO_USERS } from "@/mocks";
import type { DemoUser, Project, Role } from "@/types/domain";

const ROLE_STORAGE_KEY = "dfn.demo.role";
const AUTH_STORAGE_KEY = "dfn.demo.signed-in";
const DEFAULT_ROLE: Role = "director_general";

interface SessionContextValue {
  user: DemoUser;
  role: Role;
  /** DEMO/DEV only. */
  setRole: (role: Role) => void;
  isSignedIn: boolean;
  signIn: () => void;
  signOut: () => void;
  /** Proyectos que el rol demo puede ver. */
  availableProjects: Project[];
  hydrated: boolean;
}

const SessionContext = createContext<SessionContextValue | null>(null);

function isRole(value: string | null): value is Role {
  return value === "director_general" || value === "residente" || value === "maestro" || value === "contabilidad";
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [role, setRoleState] = useState<Role>(DEFAULT_ROLE);
  const [isSignedIn, setIsSignedIn] = useState(false);
  const [hydrated, setHydrated] = useState(false);

  // Browser-only: se lee después de hidratar para evitar mismatch SSR.
  useEffect(() => {
    const storedRole = window.localStorage.getItem(ROLE_STORAGE_KEY);
    if (isRole(storedRole)) setRoleState(storedRole);
    setIsSignedIn(window.localStorage.getItem(AUTH_STORAGE_KEY) === "true");
    setHydrated(true);
  }, []);

  const setRole = useCallback((next: Role) => {
    setRoleState(next);
    window.localStorage.setItem(ROLE_STORAGE_KEY, next);
  }, []);

  const signIn = useCallback(() => {
    setIsSignedIn(true);
    window.localStorage.setItem(AUTH_STORAGE_KEY, "true");
  }, []);

  const signOut = useCallback(() => {
    setIsSignedIn(false);
    window.localStorage.removeItem(AUTH_STORAGE_KEY);
  }, []);

  const value = useMemo<SessionContextValue>(() => {
    const user = DEMO_USERS[role];
    const availableProjects =
      user.assignedProjectIds.length === 0
        ? DEMO_PROJECTS
        : DEMO_PROJECTS.filter((project) => user.assignedProjectIds.includes(project.id));
    return { user, role, setRole, isSignedIn, signIn, signOut, availableProjects, hydrated };
  }, [role, setRole, isSignedIn, signIn, signOut, hydrated]);

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export function useSession(): SessionContextValue {
  const context = useContext(SessionContext);
  if (!context) throw new Error("useSession debe usarse dentro de SessionProvider");
  return context;
}

/** Ruta inicial según el rol demo activo. */
export function getHomeRoute(user: DemoUser): { to: string; params?: { projectId: string } } {
  switch (user.role) {
    case "director_general":
      return { to: "/portafolio" };
    case "contabilidad":
      return { to: "/contabilidad" };
    default: {
      const projectId = user.assignedProjectIds[0] ?? DEMO_PROJECTS[0].id;
      return { to: "/proyecto/$projectId", params: { projectId } };
    }
  }
}
