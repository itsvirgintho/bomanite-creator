import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Brand } from "@/components/common/Brand";
import { useAuth } from "@/contexts/auth-context";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { title: "Acceso | DFN Control" },
      { name: "description", content: "Acceso interno a DFN Control." },
    ],
  }),
  component: AuthPage,
});

/** Acceso con Supabase Auth (correo y contraseña). Sin registro público. */
function AuthPage() {
  const { login, session, initializing, authorizationContext } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resetting, setResetting] = useState(false);

  useEffect(() => {
    if (!initializing && session && authorizationContext) {
      void navigate({ to: "/portafolio", replace: true });
    }
  }, [initializing, session, authorizationContext, navigate]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setSubmitting(true);
    const result = await login(email.trim(), password);
    setSubmitting(false);
    if (!result.ok) {
      setError(result.message);
      return;
    }
    void navigate({ to: "/portafolio", replace: true });
  }

  async function handleReset() {
    setError(null);
    setNotice(null);
    if (!email.trim()) {
      setError("Escribe tu correo para enviarte el enlace de recuperación.");
      return;
    }
    setResetting(true);
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
      redirectTo: `${window.location.origin}/auth/reset-password`,
    });
    setResetting(false);
    if (resetError) console.error("[auth] resetPasswordForEmail", resetError.message);
    setNotice("Si el correo pertenece a una cuenta activa, recibirás instrucciones para restablecer la contraseña.");
  }

  return (
    <main className="relative flex min-h-screen items-center justify-center bg-surface px-4 py-10">
      {/* Acento ember ambiental */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-64 bg-[radial-gradient(60%_100%_at_50%_0%,color-mix(in_oklab,var(--color-primary)_18%,transparent),transparent)]"
      />
      <div className="relative w-full max-w-sm">
        <div className="mb-8 flex flex-col items-start">
          <Brand size="lg" />
          <span aria-hidden className="splash-bar mt-4 h-0.5 w-14 bg-primary" />
          <h1 className="mt-5 text-xl font-semibold">Acceso al sistema</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Plataforma interna de control de obra. Uso exclusivo del personal autorizado de DFN.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="panel space-y-4 p-6 shadow-raised">
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
              className="min-h-11 w-full rounded-md border border-input bg-surface px-3 text-sm transition-colors focus:border-primary"
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
              className="min-h-11 w-full rounded-md border border-input bg-surface px-3 text-sm transition-colors focus:border-primary"
            />
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="min-h-11 w-full rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground transition-all hover:shadow-ember disabled:opacity-60"
          >
            {submitting ? "Verificando…" : "Entrar"}
          </button>

          <button
            type="button"
            onClick={() => void handleReset()}
            disabled={resetting}
            className="w-full text-center text-sm text-muted-foreground underline underline-offset-4 hover:text-foreground disabled:opacity-60"
          >
            {resetting ? "Enviando…" : "¿Olvidaste tu contraseña?"}
          </button>

          {error ? (
            <p role="alert" className="rounded-md border border-danger/40 bg-danger-soft px-3 py-2 text-xs text-danger">
              {error}
            </p>
          ) : null}

          {notice ? (
            <p role="status" className="rounded-md border border-border bg-muted px-3 py-2 text-xs">
              {notice}
            </p>
          ) : null}
        </form>

        <p className="mt-4 text-center text-xs text-muted-foreground">
          No hay registro público. Las cuentas las crea Sistemas.
        </p>
      </div>
    </main>
  );
}
