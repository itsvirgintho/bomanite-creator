/**
 * AuthProvider — real Supabase Auth session + authorization context.
 * The authorization payload comes exclusively from the RPC
 * public.get_my_authorization_context(). No authorization is inferred here.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";
import type { AuthorizationContext } from "@/types/authorization";

interface AuthContextValue {
  session: Session | null;
  user: User | null;
  authorizationContext: AuthorizationContext | null;
  /** True until the initial session + context resolution finishes. */
  initializing: boolean;
  /** True while the authorization context is being fetched. */
  loadingContext: boolean;
  contextError: string | null;
  login: (email: string, password: string) => Promise<{ ok: true } | { ok: false; message: string }>;
  logout: () => Promise<void>;
  refreshAuthorizationContext: () => Promise<AuthorizationContext | null>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const GENERIC_LOGIN_ERROR = "Correo o contraseña incorrectos.";
const CONTEXT_ERROR = "No fue posible cargar tus permisos. Intenta de nuevo.";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [authorizationContext, setAuthorizationContext] = useState<AuthorizationContext | null>(null);
  const [initializing, setInitializing] = useState(true);
  const [loadingContext, setLoadingContext] = useState(false);
  const [contextError, setContextError] = useState<string | null>(null);
  const mounted = useRef(true);
  /**
   * Mientras login() está en curso, el evento SIGNED_IN de onAuthStateChange NO
   * debe disparar fetchContext: login() mismo carga el contexto de forma
   * autoritativa. Esto evita dos llamadas RPC concurrentes tras el inicio de sesión.
   */
  const loginInFlight = useRef(false);

  const fetchContext = useCallback(async (): Promise<AuthorizationContext | null> => {
    setLoadingContext(true);
    setContextError(null);
    const { data, error } = await supabase.rpc("get_my_authorization_context");
    if (error) {
      console.error("[auth] get_my_authorization_context", error.message);
      if (mounted.current) {
        setAuthorizationContext(null);
        setContextError(CONTEXT_ERROR);
        setLoadingContext(false);
      }
      return null;
    }
    const context = (data ?? null) as AuthorizationContext | null;
    if (mounted.current) {
      setAuthorizationContext(context);
      setLoadingContext(false);
    }
    return context;
  }, []);

  useEffect(() => {
    mounted.current = true;

    const { data: subscription } = supabase.auth.onAuthStateChange((event, nextSession) => {
      setSession(nextSession);
      if (event === "SIGNED_OUT" || !nextSession) {
        setAuthorizationContext(null);
        setContextError(null);
        return;
      }
      if (event === "SIGNED_IN" || event === "USER_UPDATED") {
        if (event === "SIGNED_IN" && loginInFlight.current) return;
        void fetchContext();
      }
    });

    void (async () => {
      const { data } = await supabase.auth.getSession();
      if (!mounted.current) return;
      setSession(data.session);
      if (data.session) await fetchContext();
      if (mounted.current) setInitializing(false);
    })();

    return () => {
      mounted.current = false;
      subscription.subscription.unsubscribe();
    };
  }, [fetchContext]);

  const login = useCallback<AuthContextValue["login"]>(
    async (email, password) => {
      loginInFlight.current = true;
      try {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error || !data.session) {
          if (error) console.error("[auth] signInWithPassword", error.message);
          return { ok: false, message: GENERIC_LOGIN_ERROR };
        }
        setSession(data.session);
        const context = await fetchContext();
        if (!context) return { ok: false, message: CONTEXT_ERROR };
        return { ok: true };
      } finally {
        loginInFlight.current = false;
      }
    },
    [fetchContext],
  );

  const logout = useCallback(async () => {
    await supabase.auth.signOut();
    setSession(null);
    setAuthorizationContext(null);
    setContextError(null);
  }, []);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      user: session?.user ?? null,
      authorizationContext,
      initializing,
      loadingContext,
      contextError,
      login,
      logout,
      refreshAuthorizationContext: fetchContext,
    }),
    [session, authorizationContext, initializing, loadingContext, contextError, login, logout, fetchContext],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth debe usarse dentro de AuthProvider");
  return context;
}
