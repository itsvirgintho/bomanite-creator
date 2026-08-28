# DFN Control — Foundation Phase 1

Objetivo: construir el esqueleto de la aplicación (shell, navegación por rol, contexto de proyecto, home shells por rol y sistema de diseño). Sin base de datos, sin módulos operativos, sin lógica de negocio real.

## A. Orden de implementación

1. Design tokens y sistema visual en `src/styles.css` (paleta industrial, tipografía, radios contenidos, estados accesibles).
2. Tipos de dominio (`src/types/`) y mock data centralizada (`src/mocks/`).
3. Contextos: `SessionContext` (usuario + rol activo, mock) y `ProjectContext` (proyecto activo + persistencia en localStorage).
4. Pantalla de acceso `/auth` (solo UI, sin registro público) y guardia de rutas.
5. Shell de aplicación: `AppShell` desktop (sidebar + topbar) y `MobileShell` (topbar compacto + bottom nav).
6. Navegación consciente de rol (definición declarativa de items + filtro por rol).
7. Selector de proyecto (desktop en sidebar/topbar, mobile en hoja inferior).
8. Componentes reutilizables compartidos (AttentionCard, MetricTile, StatusPill, EmptyState, LoadingState, ErrorState, SectionHeader, QuickActionButton).
9. Homes por rol: Director, Residente, Maestro, Contabilidad.
10. Rutas placeholder de módulos futuros con estado "Módulo en preparación".
11. Revisión responsive, accesibilidad y metadatos `head()` por ruta.

## B. Rutas esperadas

```text
/auth                     Acceso (correo + contraseña, UI only)
/                         Redirección según rol al home correspondiente
/portafolio               Home Director General (portafolio)
/proyecto/$projectId      Layout de proyecto (contexto activo)
  /proyecto/$projectId/   Home por rol dentro del proyecto (Residente / Maestro)
/contabilidad             Home Contabilidad (multi-proyecto)
/pendientes               Vista "Requiere tu atención" ampliada
/perfil                   Perfil y cambio de rol demo

Placeholders "Módulo en preparación":
/proyecto/$projectId/reportes
/proyecto/$projectId/avance
/proyecto/$projectId/incidencias
/proyecto/$projectId/planos
/proyecto/$projectId/programa
/proyecto/$projectId/gastos
/proyecto/$projectId/estimaciones
```

Cada ruta define su propio `head()` con título y descripción en español.

## C. Arquitectura del shell

- Desktop: sidebar fija (240px) con identidad DFN, selector de proyecto, grupos de navegación (Operación, Control, Financiero) y pie con usuario/rol; contenido con topbar de contexto (proyecto activo, breadcrumb, acciones).
- Mobile: topbar mínima (proyecto activo + acceso a perfil) y bottom navigation de máximo 5 destinos, adaptada por rol. No es el layout de escritorio comprimido: densidad, orden y acciones cambian.
- Maestro en mobile: sin sidebar, sin tablas, tarjetas grandes con jerarquía "Hoy → Pendiente → Acciones rápidas" y 4 botones grandes (Reporte diario, Foto, Gasto, Incidencia).

## D. Navegación consciente de rol

Un único módulo declarativo `src/config/navigation.ts` con items `{ id, label, to, icon, roles, financialLevel, surface: 'desktop' | 'mobile' | 'both' }`. El shell filtra por rol activo y nivel financiero. En esta fase el filtro es de UI; la autorización real se aplicará después con RLS en Supabase.

## E. Selector de proyecto

- Director y Contabilidad: multi-proyecto, pueden operar sin proyecto activo (vista portafolio) y elegir uno para hacer drill-down.
- Residente y Maestro: inician con su proyecto asignado; Maestro no puede cambiar a proyectos no asignados.
- El proyecto activo vive en `ProjectContext`, se refleja en la URL (`/proyecto/$projectId/...`) y se recuerda en localStorage.

## F. Homes por rol (contenido de la fase)

- Director: salud por proyecto (verde/ámbar/rojo con etiqueta textual, nunca solo color), avance programado vs real, y bloque "Requiere tu atención" de portafolio.
- Residente: "Requiere tu atención" primero (reportes por revisar, cantidades por validar, gastos por revisar, incidencias vencidas, actividades bloqueadas), luego avance programado, avance real, desviación, días transcurridos/restantes y personal en obra.
- Maestro: proyecto actual, trabajo de hoy, cuadrilla, reporte pendiente/devuelto, incidencias asignadas, planos vigentes y acciones rápidas. Sin contrato, precios unitarios, margen ni cobranza.
- Contabilidad: gastos sin factura, reembolsos pendientes, facturas con problema, documentación pendiente. Los filtros (proyecto, periodo, proveedor, pago, factura) se dejan previstos en la interfaz de datos, no funcionales aún.

Toda métrica se renderiza mediante un componente que ya acepta `drilldownTo`, para que ningún número quede muerto cuando existan datos reales.

## G. Componentes reutilizables

`AppShell`, `MobileBottomNav`, `SidebarNav`, `ProjectSwitcher`, `RoleBadge`, `PageHeader`, `AttentionPanel`, `AttentionItem`, `MetricTile`, `ProgressCompare`, `HealthIndicator`, `StatusPill`, `QuickActionGrid`, `DataSection`, `EmptyState`, `LoadingState` (skeletons), `ErrorState`, `ModulePlaceholder`, `DemoDataBanner`.

## H. Estados

- Carga: skeletons con la forma del contenido; nunca spinners de página completa dentro del shell.
- Vacío: título, explicación breve y acción sugerida cuando aplique ("No hay reportes por revisar").
- Error: mensaje claro, botón reintentar, sin trazas técnicas.
- Módulo futuro: `ModulePlaceholder` con "Módulo en preparación" y descripción de lo que contendrá.

## I. Diseño y tokens

Tokens semánticos en `src/styles.css` (oklch): superficie clara neutra, gris industrial, acento sobrio, y estados `success/warning/danger/info` con foreground legible. Tipografía técnica de alta legibilidad, escala de espaciado compacta en escritorio y generosa en móvil, radios pequeños, sombras mínimas. Sin gradientes decorativos, glassmorphism ni tipografía de marketing. Ningún color literal en componentes.

## J. Autenticación (esta fase)

Pantalla `/auth` con correo y contraseña, sin registro público ni recuperación funcional. La sesión es mock en `SessionContext` con un selector de rol de demostración para validar las cuatro experiencias. Estructura preparada para sustituir el proveedor mock por Supabase Auth sin tocar los componentes.

## K. Accesibilidad

Landmarks semánticos, foco visible, objetivos táctiles ≥44px en móvil, contraste AA, estados nunca dependientes solo de color, etiquetas ARIA en navegación e iconos, orden de tabulación coherente, textos en español.

## L. Organización de carpetas

```text
src/
  components/
    layout/      AppShell, SidebarNav, MobileBottomNav, ProjectSwitcher
    common/      MetricTile, StatusPill, EmptyState, LoadingState, ErrorState...
    attention/   AttentionPanel, AttentionItem
    ui/          shadcn base
  config/        navigation.ts, roles.ts
  contexts/      session-context.tsx, project-context.tsx
  types/         domain.ts (Role, Project, AttentionItem, Metric, ...)
  mocks/         index.ts (todo el mock data, marcado DEMO)
  routes/        rutas TanStack
```

## M. Tipos y mock data

Tipos de dominio en inglés (`Role`, `Project`, `ProjectHealth`, `AttentionItem`, `MetricValue`, `CrewSummary`, `DrawingRef`), UI en español. Todo el mock vive en `src/mocks/`, exportado con prefijo `DEMO_` y visible en pantalla mediante `DemoDataBanner` en vistas con datos financieros.

## N. Fuera de alcance en esta fase

Sin esquema de base de datos, tablas, migraciones ni RLS. Sin Reportes, Gastos, Estimaciones, Planos, Avance, Programa ni Incidencias funcionales. Sin subida de archivos, sin IA, sin Autodesk, sin empaquetado nativo, sin offline, sin pagos, sin registro público.

## O. Riesgos a resolver antes de implementar

1. Confirmar si el cambio de rol de demostración debe ser visible o quedar oculto tras el perfil.
2. Confirmar si Contabilidad debe vivir fuera del contexto de proyecto (propuesta: sí, multi-proyecto).
3. Confirmar la marca visual: color de acento, logotipo y nombre exacto a mostrar.
4. Confirmar si Director inicia siempre en portafolio aun con un solo proyecto autorizado.

## P. Checklist de aceptación

- [ ] `/` redirige al home correcto según rol.
- [ ] Las cuatro experiencias de rol son navegables y visualmente distintas.
- [ ] Desktop usa sidebar; mobile usa bottom nav con layouts genuinamente adaptados.
- [ ] Maestro nunca ve información financiera sensible ni proyectos no asignados.
- [ ] "Requiere tu atención" es el primer bloque en Residente, Contabilidad y Director.
- [ ] Selector de proyecto funcional y persistente, con reglas por rol.
- [ ] Rutas de módulos futuros muestran "Módulo en preparación".
- [ ] Estados de carga, vacío y error implementados en todos los homes.
- [ ] Cero colores literales en componentes; todo por tokens.
- [ ] Mock data centralizada en `src/mocks/` y claramente etiquetada.
- [ ] Sin tablas, migraciones ni lógica de backend.
- [ ] Build y typecheck limpios; cada ruta con `head()` propio.
