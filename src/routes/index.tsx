import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { SplashScreen } from "@/components/common/SplashScreen";
import { useAuth } from "@/contexts/auth-context";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Inicio | DFN Control" },
      { name: "description", content: "Acceso al panel operativo de DFN Control." },
    ],
  }),
  component: Index,
});

/** Redirección según la sesión real de Supabase (se resuelve en cliente). */
function Index() {
  const { session, initializing } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (initializing) return;
    void navigate({ to: session ? "/portafolio" : "/auth", replace: true });
  }, [initializing, session, navigate]);

  return <SplashScreen />;
}
