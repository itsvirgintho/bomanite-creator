import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { LoadingState } from "@/components/common/States";
import { getHomeRoute, useSession } from "@/contexts/session-context";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Inicio | DFN Control" },
      { name: "description", content: "Acceso al panel operativo de DFN Control." },
    ],
  }),
  component: Index,
});

/** Redirección según el rol demo activo (se resuelve en cliente tras hidratar). */
function Index() {
  const { user, isSignedIn, hydrated } = useSession();
  const navigate = useNavigate();

  useEffect(() => {
    if (!hydrated) return;
    if (!isSignedIn) {
      void navigate({ to: "/auth", replace: true });
      return;
    }
    const home = getHomeRoute(user);
    void navigate({ to: home.to, params: home.params, replace: true } as never);
  }, [hydrated, isSignedIn, user, navigate]);

  return (
    <div className="mx-auto max-w-3xl p-6">
      <LoadingState rows={2} />
    </div>
  );
}
