import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import type { FormEvent } from "react";
import { Brand } from "@/components/common/Brand";
import { getHomeRoute, useSession } from "@/contexts/session-context";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Acceso | DFN Control" },
      { name: "description", content: "Acceso interno a DFN Control." },
    ],
  }),
  component: AuthPage,
});

/**
 * Pantalla de acceso — Foundation Phase 1.
 * Autenticación simulada: no valida credenciales ni consulta un backend.
 * Se sustituirá por Supabase Auth. No existe registro público.
 */
function AuthPage() {
  const { signIn, user } = useSession();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [notice, setNotice] = useState<string | null>(null);

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    signIn();
    const home = getHomeRoute(user);
    void navigate({ to: home.to, params: home.params, replace: true } as never);
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-surface px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6">
          <Brand size="lg" />
          <h1 className="mt-4 text-lg font-semibold">Acceso al sistema</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Plataforma interna de control de obra. Uso exclusivo del personal autorizado de DFN.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="panel space-y-4 p-5">
          <div>
            <label htmlFor="email" className="mb-1.5 block text-sm font-medium">
              Correo corporativo
            </label>
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="username"
              required
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              placeholder="nombre@dfn.mx"
              className="min-h-11 w-full rounded-md border border-input bg-card px-3 text-sm"
            />
          </div>

          <div>
            <label htmlFor="password" className="mb-1.5 block text-sm font-medium">
              Contraseña
            </label>
            <input
              id="password"
              name="password"
              type="password"
              autoComplete="current-password"
              required
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="min-h-11 w-full rounded-md border border-input bg-card px-3 text-sm"
            />
          </div>

          <button
            type="submit"
            className="min-h-11 w-full rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground hover:opacity-95"
          >
            Entrar
          </button>

          <button
            type="button"
            onClick={() =>
              setNotice("La recuperación de contraseña se habilitará al conectar la autenticación real.")
            }
            className="w-full text-center text-sm text-muted-foreground underline underline-offset-4"
          >
            ¿Olvidaste tu contraseña?
          </button>

          {notice ? (
            <p role="status" className="rounded-md border border-border bg-muted px-3 py-2 text-xs">
              {notice}
            </p>
          ) : null}
        </form>

        <p className="mt-4 rounded-md border border-dashed border-border-strong bg-muted px-3 py-2 text-xs text-muted-foreground">
          Fase 1: el acceso es simulado y no valida credenciales. El rol de demostración se cambia en
          Perfil.
        </p>
        <p className="mt-3 text-xs text-muted-foreground">
          No hay registro público. Las cuentas las crea Sistemas.
        </p>
      </div>
    </main>
  );
}
