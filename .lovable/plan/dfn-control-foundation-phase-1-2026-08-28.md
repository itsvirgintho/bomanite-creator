# DFN Control — Foundation Phase 1

Objetivo: construir el esqueleto de la aplicación (shell, navegación por rol, contexto de proyecto, home shells por rol y sistema de diseño). Sin base de datos, sin módulos operativos, sin lógica de negocio real.

## A. Orden de implementación

1. Design tokens y sistema visual en `src/styles.css` (neutros industriales, tipografía, radios contenidos, estados accesibles). Marca temporal: wordmark de texto "DFN CONTROL", centralizado y reemplazable.
2. Tipos de dominio (`src/types/`) y mock data centralizada (`src/mocks/`).
3. Contextos: `SessionContext` (usuario + rol demo) y `ProjectContext` (proyecto activo derivado de la URL, con fallback client-side tras hidratación).
4. Pantalla de acceso `/auth` (solo UI, sin registro público) y guardia de rutas.
5. Shell de aplicación: `AppShell` desktop (sidebar + topbar) y `MobileShell` (topbar compacto + bottom nav).
6. Navegación consciente de rol (definición declarativa de items + filtro por rol).
7. Selector de proyecto (desktop en sidebar/topbar, mobile en hoja inferior).
8. Componentes reutilizables compartidos (AttentionPanel, MetricTile, StatusPill, EmptyState, LoadingState, ErrorState, PageHeader, QuickActionGrid, DemoDataNotice).
9. Homes por rol: Director, Residente, Maestro, Contabilidad.
10. Rutas placeholder de módulos futuros con estado "Módulo en preparación".
11. Revisión responsive, accesibilidad y `head()` con títulos claros por ruta.

## B. Rutas esperadas

```text
/auth                     Acceso (correo + contraseña, UI only)
/                         Redirección según rol al home correspondiente
/portafolio               Home Director General (siempre inicia aquí, sin redirigir a proyecto)
/proyecto/$projectId      Layout de proyecto (contexto canónico desde la URL)
  /proyecto/$projectId/   Home por rol dentro del proyecto (Residente / Maestro)
/contabilidad             Home Contabilidad (multi-proyecto, sin proyecto activo requerido)
/perfil                   Perfil y controles DEMO/DEV (cambio de rol)

Placeholders "Módulo en preparación":
/proyecto/$projectId/reportes
/proyecto/$projectId/avance
/proyecto/$projectId/incidencias
/proyecto/$projectId/planos
/proyecto/$projectId/programa
/proyecto/$projectId/gastos
/proyecto/$projectId/estimaciones
```

Cada ruta usa `head()` de TanStack para títulos claros (`Portafolio | DFN Control`, `Maraluna | DFN Control`). Aplicación interna: no se invierte esfuerzo en SEO elaborado de rutas protegidas.

## C. Arquitectura del shell

- Desktop: sidebar fija (240px) con wordmark DFN CONTROL, selector de proyecto, grupos de navegación (Operación, Control, Financiero) y pie con usuario/rol; contenido con topbar de contexto (proyecto activo, breadcrumb, acciones).
- Mobile: topbar mínima (proyecto activo + acceso a perfil) y bottom navigation de máximo 5 destinos, adaptada por rol. No es el layout de escritorio comprimido: densidad, orden y acciones cambian.
- Maestro en mobile: sin sidebar, sin tablas, tarjetas grandes con jerarquía "Hoy → Pendiente → Acciones rápidas" y 4 botones grandes (Reporte diario, Foto, Gasto, Incidencia).

## D. Navegación consciente de rol

Un único módulo declarativo `src/config/navigation.ts` con items `{ id, label, to, icon, roles, financialLevel, surface: 'desktop' | 'mobile' | 'both' }`. El shell filtra por rol activo y nivel financiero. En esta fase es exclusivamente demostración de UX: la visibilidad en UI no es autorización. La autorización real se aplicará después con Supabase Auth, membresía de proyecto, permisos y RLS. Esta distinción queda documentada en el código (`// UI visibility only — NOT authorization`).

## E. Selector de proyecto y SSR

- La fuente canónica del proyecto activo es la URL: `/proyecto/$projectId/...`. Nada de leer proyecto activo desde localStorage durante render o SSR.
- `ProjectContext` lee el `projectId` de la ruta. localStorage solo se usa client-side, en `useEffect` tras hidratación, para recordar el último proyecto y ofrecer selección por defecto en el selector.
- Sin acceso a browser APIs en module scope, loaders o render; se evita hydration mismatch con `useEffect`/`useHydrated` donde aplique.
- Director y Contabilidad operan sin proyecto activo (portafolio / contabilidad global) y eligen un proyecto para drill-down. Director General siempre inicia en `/portafolio`, incluso con un solo proyecto.
- Residente y Maestro inician con su proyecto asignado; Maestro no puede cambiar a proyectos no asignados.

## F. Homes por rol (contenido de la fase)

- Director: salud por proyecto (verde/ámbar/rojo con etiqueta textual, nunca solo color), avance programado vs real, y bloque "Requiere tu atención" de portafolio.
- Residente: "Requiere tu atención" primero (reportes por revisar, cantidades por validar, gastos por revisar, incidencias vencidas, actividades bloqueadas), luego avance programado, avance real, desviación, días transcurridos/restantes y personal en obra.
- Maestro: proyecto actual, trabajo de hoy, cuadrilla, reporte pendiente/devuelto, incidencias asignadas, planos vigentes y acciones rápidas. Sin contrato, precios unitarios, margen ni cobranza.
- Contabilidad: gastos sin factura, reembolsos pendientes, facturas con problema, documentación pendiente. Los filtros (proyecto, periodo, proveedor, pago, factura) se dejan previstos en la interfaz de datos, no funcionales aún.

Toda métrica se renderiza mediante un componente que ya acepta `drilldownTo`, para que ningún número quede muerto cuando existan datos reales. Toda vista con datos demo muestra de forma clara pero discreta la leyenda "Datos de demostración" (en todos los homes por rol, no solo financieros).

## G. Componentes reutilizables

`AppShell`, `MobileBottomNav`, `SidebarNav`, `ProjectSwitcher`, `RoleBadge`, `PageHeader`, `AttentionPanel`, `AttentionItem`, `MetricTile`, `ProgressCompare`, `HealthIndicator`, `StatusPill`, `QuickActionGrid`, `EmptyState`, `LoadingState` (skeletons), `ErrorState`, `ModulePlaceholder`, `DemoDataNotice`, `DemoRoleSwitcher`.

## H. Estados

- Carga: skeletons con la forma del contenido; nunca spinners de página completa dentro del shell.
- Vacío: título, explicación breve y acción sugerida cuando aplique ("No hay reportes por revisar").
- Error: mensaje claro, botón reintentar, sin trazas técnicas.
- Módulo futuro: `ModulePlaceholder` con "Módulo en preparación" y descripción de lo que contendrá.

## I. Diseño y tokens

Tokens semánticos en `src/styles.css` (oklch): superficie clara neutra, gris industrial, acento sobrio y temporal (paleta corporativa definitiva pendiente), y estados `success/warning/danger/info` con foreground legible. Marca (wordmark, acento) centralizada en tokens y un único componente de marca, reemplazable sin tocar componentes. Tipografía técnica de alta legibilidad, escala de espaciado compacta en escritorio y generosa en móvil, radios pequeños, sombras mínimas. Sin gradientes decorativos, glassmorphism ni tipografía de marketing. Ningún color literal ni branding hard-codeado en componentes.

## J. Autenticación y cambio de rol DEMO

Pantalla `/auth` con correo y contraseña, sin registro público ni recuperación funcional. La sesión es mock en `SessionContext`. El cambio de rol (Director General, Residente de Obra, Maestro de Obra, Contabilidad) vive únicamente en `/perfil` dentro de un bloque marcado "Controles DEMO/DEV", aislado en `DemoRoleSwitcher`, con comentarios que lo señalan como temporal. Nunca forma parte de la navegación de negocio, nunca es capacidad de producción, y está diseñado para eliminarse intacto cuando lleguen Supabase Auth y la membresía real.

## K. Accesibilidad

Landmarks semánticos, foco visible, objetivos táctiles ≥44px en móvil, contraste AA, estados nunca dependientes solo de color, etiquetas ARIA en navegación e iconos, orden de tabulación coherente, textos en español.

## L. Organización de carpetas

```text
src/
  components/
    layout/      AppShell, SidebarNav, MobileBottomNav, ProjectSwitcher
    common/      MetricTile, StatusPill, EmptyState, LoadingState, ErrorState...
    attention/   AttentionPanel, AttentionItem
    demo/        DemoRoleSwitcher, DemoDataNotice (marcados DEMO/DEV)
    ui/          shadcn base
  config/        navigation.ts, roles.ts
  contexts/      session-context.tsx, project-context.tsx
  types/         domain.ts (Role, Project, AttentionItem, Metric, ...)
  mocks/         index.ts (todo el mock data, marcado DEMO)
  routes/        rutas TanStack
```

## M. Tipos y mock data

Tipos de dominio en inglés (`Role`, `Project`, `ProjectHealth`, `AttentionItem`, `MetricValue`, `CrewSummary`, `DrawingRef`), UI en español. Todo el mock vive en `src/mocks/`, exportado con prefijo `DEMO_`, y toda vista que lo use muestra "Datos de demostración" mediante `DemoDataNotice`.

## N. Fuera de alcance en esta fase

Sin esquema de base de datos, tablas, migraciones ni RLS. Sin autenticación real. Sin Reportes, Gastos, Estimaciones, Planos, Avance, Programa ni Incidencias operativos. Sin subida de archivos, sin IA, sin Autodesk, sin empaquetado nativo, sin offline, sin pagos, sin registro público. Sin servicios de terceros de pago ni dependencias innecesarias: stack actual de Lovable + Supabase Free + GitHub Free.

## O. Decisiones y riesgos resueltos

1. Cambio de rol: aprobado como DEMO/DEV aislado en `/perfil`, removible.
2. Contabilidad: workspace multi-proyecto global, sin proyecto activo requerido.
3. Director: siempre inicia en `/portafolio`.
4. Marca: wordmark temporal "DFN CONTROL" + tokens neutros industriales, centralizados.
5. Riesgo restante: al llegar Supabase Auth, eliminar `SessionContext` mock y `DemoRoleSwitcher` sin tocar shell ni navegación; el aislamiento propuesto lo garantiza.

## P. Checklist de aceptación

- [ ] `/` redirige al home correcto según rol; Director siempre aterriza en `/portafolio`.
- [ ] Las cuatro experiencias de rol son navegables y visualmente distintas.
- [ ] Desktop usa sidebar; mobile usa bottom nav con layouts genuinamente adaptados.
- [ ] Maestro nunca ve información financiera sensible ni proyectos no asignados.
- [ ] "Requiere tu atención" es el primer bloque en Residente, Contabilidad y Director.
- [ ] Proyecto activo proviene de la URL; localStorage solo como fallback tras hidratación; cero hydration mismatch.
- [ ] Contabilidad funciona sin proyecto activo y permite elegir proyecto para drill-down.
- [ ] Cambio de rol DEMO aislado en `/perfil`, claramente marcado DEMO/DEV, fuera de la navegación de negocio.
- [ ] Toda vista con datos mock muestra "Datos de demostración" de forma discreta.
- [ ] Rutas de módulos futuros muestran "Módulo en preparación".
- [ ] Estados de carga, vacío y error implementados en todos los homes.
- [ ] Marca centralizada en tokens/componente único; cero colores literales ni branding hard-codeado.
- [ ] Navegación por rol documentada como visibilidad de UX, no autorización.
- [ ] Mock data centralizada en `src/mocks/` con prefijo `DEMO_`.
- [ ] `head()` con títulos claros por ruta (`Portafolio | DFN Control`, etc.).
- [ ] Sin tablas, migraciones, autenticación real ni lógica de backend.
- [ ] Sin dependencias nuevas innecesarias ni servicios de pago.
- [ ] Build y typecheck limpios.
