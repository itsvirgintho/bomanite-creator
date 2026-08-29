import { BRAND_NAME } from "@/components/common/Brand";

/**
 * Pantalla de carga de arranque: wordmark DFN CONTROL sobre carbón.
 * Se muestra mientras se resuelve la sesión inicial de Supabase.
 */
export function SplashScreen() {
  return (
    <div
      role="status"
      aria-label="Cargando DFN Control"
      className="flex min-h-screen flex-col items-center justify-center bg-background px-6"
    >
      <div className="flex flex-col items-center">
        <span
          aria-hidden
          className="splash-bar mb-5 h-0.5 w-16 bg-primary"
        />
        <p className="splash-wordmark font-display text-xl font-semibold tracking-[0.22em] text-foreground uppercase sm:text-2xl">
          {BRAND_NAME}
        </p>
        <p className="mt-3 text-xs tracking-[0.08em] text-muted-foreground uppercase">
          Control de obra · DFN
        </p>
      </div>
    </div>
  );
}
