# DFN Control — Rediseño Visual (solo presentación, sin cambios funcionales)

## Objetivo
Impacto visual fuerte sin tocar lógica de negocio, autenticación, RLS, rutas ni datos. Todo el cambio vive en tokens CSS, componentes de presentación y un splash de carga.

## Decisiones fijadas por el usuario
- **Paleta**: Charcoal & Ember — base carbón oscuro `#1a1a1a` / `#2d2d2d` / `#4a4a4a`, acento ember `#e85d3a`.
- **Tipografía**: Urbanist (titulares) + Epilogue (cuerpo), cargadas vía `<link>` en `__root.tsx` (nunca `@import` de URL en styles.css).
- **Layout**: Bento grid para paneles/home (tarjetas de tamaños mixtos, densidad controlada).
- **Sesión**: recordar siempre — Supabase ya persiste sesión en localStorage por defecto; se verifica la config y se elimina cualquier cierre de sesión forzado al recargar. Sin casilla "Recordarme".

## Alcance de cambios

### 1. Sistema de diseño (`src/styles.css`)
- Reemplazar tokens `:root` por tema carbón oscuro: background carbón, cards grafito, acento ember, estados (success/warning/danger/info) recalibrados para dark mode con buen contraste.
- Mantener nombres semánticos existentes (`--background`, `--primary`, `--accent`, etc.) para no tocar componentes; color nunca como único indicador de estado (se conservan íconos/etiquetas).
- Sombras y bordes ajustados a superficies oscuras.
- Tokens `--font-display: Urbanist`, `--font-sans: Epilogue`.

### 2. Splash de carga con logo
- Componente `SplashScreen`: logo tipográfico "DFN CONTROL" (wordmark Arial simple/limpio, según descripción del usuario — se renderiza como texto, no imagen) con animación sutil de entrada, sobre fondo carbón.
- Mostrarse mientras `initializing` del auth context (reemplaza el `LoadingState` genérico de `AppShell` e `index.tsx`). Transición suave al shell al resolver la sesión.
- Marca actualizada en `Brand.tsx` manteniendo el punto único de definición.

### 3. Pantalla de login (`/auth`)
- Rediseño: fondo carbón, wordmark DFN CONTROL prominente, tarjeta de formulario con acento ember, focos visibles. Misma funcionalidad (email/password, reset).

### 4. Shell y navegación
- Sidebar oscura refinada: item activo con indicador ember, jerarquía tipográfica Urbanist.
- Header/contexto, `MobileBottomNav`, `ProjectSwitcher` restilizados con tokens nuevos.

### 5. Bento grid en vistas principales
- `MaestroHome`, `ResidentHome`, `DirectorProjectHome`, `AttentionPanel`, `MetricTile`: reorganizar en bento (tile destacada + tiles secundarias) usando solo reordenación de layout/clases; sin cambiar datos ni queries.

### 6. Persistencia de sesión
- Verificar `src/integrations/supabase/client.ts`: `persistSession: true`, `autoRefreshToken: true`. Confirmar que recargar o cerrar/abrir el navegador mantiene la sesión y que `/` redirige a `/portafolio` sin login repetido.

## Fuera de alcance
- Base de datos, RLS, migraciones, RPC, lógica de autorización, rutas nuevas, datos mock.
- No se eliminan funcionalidades; solo presentación.

## Verificación
- Typecheck + build OK.
- Playwright: splash visible al cargar, login rediseñado, shell dark, bento en homes, sesión persistente tras recarga, móvil (bottom nav) intacto.
