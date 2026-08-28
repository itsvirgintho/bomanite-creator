import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { Brand } from "@/components/common/Brand";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth_/reset-password")({
  head: () => ({
    meta: [
      { title: "Restablecer contraseña | DFN Control" },
      { name: "description", content: "Define una nueva contraseña para tu cuenta de DFN Control." },
    ],
  }),
  component: ResetPasswordPage,
});

/** Llega desde el correo de recuperación de Supabase (type=recovery). Sin registro público. */
function ResetPasswordPage() {
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);
  const [hasSession, setHasSession] = useState(false);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  useEffect(() => {
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) setHasSession(true);
    });
    void supabase.auth.getSession().then(({ data }) => {
      setHasSession(Boolean(data.session));
      setReady(true);
    });
    return () => subscription.subscription.unsubscribe();
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError("La contraseña debe tener al menos 8 caracteres.");
      return;
    }
    if (password !== confirm) {
      setError("Las contraseñas no coinciden.");
      return;
    }
    setSubmitting(true);
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setSubmitting(false);
    if (updateError) {
      console.error("[auth] updateUser", updateError.message);
      setError("No fue posible actualizar la contraseña. Solicita un nuevo enlace de recuperación.");
      return;
    }
    setDone(true);
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-surface px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6">
          <Brand size="lg" />
          <h1 className="mt-4 text-lg font-semibold">Nueva contraseña</h1>
        </div>

        {!ready ? (
          <p className="text-sm text-muted-foreground">Verificando enlace…</p>
        ) : done ? (
          <div className="panel space-y-4 p-5">
            <p className="text-sm">Tu contraseña fue actualizada.</p>
            <button
              type="button"
              onClick={() => void navigate({ to: "/auth", replace: true })}
              className="min-h-11 w-full rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground"
            >
              Ir al acceso
            </button>
          </div>
        ) : !hasSession ? (
          <div className="panel space-y-3 p-5">
            <p className="text-sm">
              El enlace de recuperación no es válido o expiró. Solicita uno nuevo desde la pantalla de
              acceso.
            </p>
            <button
              type="button"
              onClick={() => void navigate({ to: "/auth", replace: true })}
              className="min-h-11 w-full rounded-md border border-border-strong px-4 text-sm font-medium"
            >
              Volver al acceso
            </button>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="panel space-y-4 p-5">
            <div>
              <label htmlFor="password" className="mb-1.5 block text-sm font-medium">
                Nueva contraseña
              </label>
              <input
                id="password"
                type="password"
                autoComplete="new-password"
                required
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                className="min-h-11 w-full rounded-md border border-input bg-card px-3 text-sm"
              />
            </div>
            <div>
              <label htmlFor="confirm" className="mb-1.5 block text-sm font-medium">
                Confirmar contraseña
              </label>
              <input
                id="confirm"
                type="password"
                autoComplete="new-password"
                required
                value={confirm}
                onChange={(event) => setConfirm(event.target.value)}
                className="min-h-11 w-full rounded-md border border-input bg-card px-3 text-sm"
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              className="min-h-11 w-full rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground disabled:opacity-60"
            >
              {submitting ? "Guardando…" : "Guardar contraseña"}
            </button>
            {error ? (
              <p role="alert" className="rounded-md border border-danger/40 bg-danger/10 px-3 py-2 text-xs text-danger">
                {error}
              </p>
            ) : null}
          </form>
        )}
      </div>
    </main>
  );
}
