# Plan: Gamificación + Registro en Supabase + "Hoy corrí" + Analíticas

## Resumen general

Convertir CardioFeliz (React 18 + Vite + Tailwind, PWA, hoy 100% localStorage) en una app con loop de hábito estilo Duolingo:

- **Persistencia**: cada día de entrenamiento terminado y cada corrida se guardan en Supabase (free tier), usando el **mismo login que PlanDental** (mismo proyecto, mismos usuarios y contraseñas). Tablas propias con prefijo `cf_`.
- **"Hoy corrí"**: botón de un toque (30 min por defecto) + paso opcional para ajustar minutos, km, cinta/calle, sensación y fecha.
- **Gamificación**: racha diaria con congeladores + racha semanal, XP y niveles, meta semanal con anillos (3 entrenamientos + 2 corridas), logros/insignias, mensaje del coach al abrir la app.
- **Analíticas**: nuevo ícono en el header (a la izquierda de "silenciar") que abre una vista con gráficos (Recharts) y estadísticas.

### Decisiones tomadas con el usuario
| Tema | Decisión |
|---|---|
| Identidad | Login compartido con PlanDental: mismo proyecto Supabase (`wzxgecdpfpnlzaawdyjx`), usuario + contraseña (`<usuario>@app.local`). Sin login anónimo. Pensado para multiusuario a futuro (cada uno con su rutina) |
| Aislamiento | Tablas `cf_*` solamente; nada de PlanDental se modifica. `public.profiles` se lee en solo lectura |
| "Hoy corrí" | 1 toque = 30 min; paso opcional: minutos, km (opcional), cinta/calle, sensación |
| Calorías | Estimadas con el peso de Juli (se carga una vez) |
| Gamificación | Completa: racha + congeladores, XP/niveles, anillos semanales, logros, mensaje al abrir |
| Racha | Diaria: cuenta entrenamiento, corrida o "descanso activo" (1 toque). Congelador: 1 cada 5 días de racha, máx. 2, se usa solo. Más racha semanal (semanas con meta cumplida) |
| Gráficos | Recharts |
| Extras de gamificación | Desafíos semanales rotativos, misiones diarias con XP extra, mascota/coach con personalidad que evoluciona con el nivel |
| Modo vacaciones | Pausa que congela la racha mientras está activo; al volver, el coach entra en modo "¡Hay que recuperar!" los primeros días |

### Hallazgos del código que condicionan el plan
- [`src/hooks/useWorkoutStorage.ts`](src/hooks/useWorkoutStorage.ts:56): `markBlockComplete` guarda `tipoBloque: 'EMOM'` fijo (bug); hay que pasar el tipo real.
- `completedDays` / `completedBlocks` son booleanos permanentes: `DayCard` muestra "COMPLETADO HOY" para siempre. Con gamificación el estado "completado" debe derivarse de las actividades de la **semana actual** (y de hoy para los bloques).
- El fin de día se detecta solo cuando termina el **último bloque** ([`src/App.tsx`](src/App.tsx:59)). Decisión propuesta: el día se considera terminado cuando **todos** los bloques del día están completados (sin importar el orden).
- No hay React Router: la navegación es por `ViewMode` en [`src/App.tsx`](src/App.tsx:13); se agrega `'analytics'`.
- [`public/sw.js`](public/sw.js) usa cache-first para todo GET: hay que excluir el dominio de Supabase.
- La app se usa en el gimnasio (posible mala señal): el guardado debe ser **local-first** con cola de sincronización.
- No hay tests ni librería de gráficos. Header usa `lucide-react` (ícono propuesto: `BarChart3`).

### Modelo de datos (Supabase)
- `cf_profiles`: `user_id` (PK, = `auth.uid()`), `display_name`, `weight_kg`, `created_at`.
- `cf_activities`: `id` (uuid generado en cliente, idempotente), `user_id`, `type` (`workout_day` | `run` | `active_rest`), `occurred_on` (date local), `started_at`, `duration_seconds`, `day_id` (dia_1..3, solo workout), `blocks_completed`, `rounds_total`, `distance_km` (null), `run_location` (`cinta` | `calle`, null), `feeling` (1–5, null), `calories_kcal` (estimadas al guardar), `xp_earned`.
- `cf_achievements`: `user_id`, `achievement_id`, `unlocked_at` (PK compuesta).
- `cf_vacations`: `id`, `user_id`, `start_on` (date), `end_on` (date, null mientras esté activa). Un solo período abierto por usuario.
- RLS en las 4 tablas: cada usuario solo lee/escribe filas con `user_id = auth.uid()`.
- Racha, congeladores, nivel, anillos, progreso de logros, desafíos y misiones **no se guardan**: se derivan con funciones puras a partir de `activities` + `vacations` (una sola fuente de verdad, sin inconsistencias entre dispositivos). El XP de desafíos/misiones se suma en el cálculo derivado (no hay tabla de "reclamos").

### Reglas de juego propuestas (todas en un único archivo de configuración, ajustables)
- **XP**: día de entrenamiento 100 (+10 por bloque extra completado), corrida 60 (+1 cada 5 min sobre 30, +bonus si se informan km), descanso activo 20, bonus semana perfecta 150, bonus por hitos de racha.
- **Niveles**: curva creciente con nombres temáticos.
- **Calorías**: `MET × peso_kg × horas`. Entrenamiento HIIT/funcional MET ~8; correr MET según velocidad si hay km (si no, MET fijo moderado); cinta/calle con mismo cálculo. Se muestra como "estimado".
- **Semana**: lunes a domingo; meta = 3 entrenamientos + 2 corridas.
- **Logros (ejemplos)**: primer entreno, primera corrida, rachas 3/7/14/30/60/100, semana perfecta, 4 semanas perfectas seguidas, 10/25/50 entrenos, 50/100/250 km, corrida ≥45/60 min, madrugadora, "volví" (retorno tras 7+ días), primer congelador usado.
- **Mensaje del coach al abrir**: reglas según contexto (racha en riesgo, vuelta tras pausa, meta semanal cerca, elogio por ayer, congelador ganado). Solo dentro de la app; push notifications quedan fuera de alcance (requieren servidor/web push).

### Desafíos semanales, misiones diarias, mascota y vacaciones (nuevo)
- **Desafíos semanales rotativos**: 1 desafío por semana elegido de un catálogo de forma determinista (semilla = semana ISO; mismo resultado en todos los dispositivos). Ejemplos: "3 días seguidos activos", "Corré 10 km esta semana", "Sumá 150 min activos", "Entrená 2 días antes del mediodía", "Una corrida de 40+ min". Dan XP extra y cuentan para logros. Se evitan desafíos imposibles (ej. los de km solo aplican si se informan km; si no, se elige otro).
- **Misiones diarias**: 2–3 por día desde un catálogo (ej. "Completá un bloque", "Registrá tu corrida", "Descanso activo de 10 min", "Terminá el día completo"), con XP extra y bonus por completar todas. Se adaptan a si es día de descanso o de entrenamiento y al avance de la meta semanal (si falta una corrida, aparece la misión de correr).
- **Mascota/coach con personalidad**: personaje en SVG liviano (sin assets pesados) con 4–5 etapas que evolucionan por nivel, tono y frases propias, y estados de ánimo (contento, orgulloso, preocupado, "modo recuperar"). Es la voz de los mensajes de apertura; aparece en Home y en el cierre de día.
- **Modo vacaciones**: toggle desde Home/Cuenta (fecha de inicio, fin opcional). Mientras está activo: la racha **no se rompe ni consume congeladores**, la semana queda "pausada" (no rompe la racha semanal), se ocultan misiones y desafíos y el coach muestra mensajes de descanso. Si igual se registra actividad, suma XP normal. Al desactivar: el coach entra en modo **"¡Hay que recuperar!"** los primeros días (propuesta: 3), con mensajes cercanos y una misión de vuelta suave; a validar: bonus de XP ×1.5 en esos días ("bonus de regreso"). Sin tope duro de duración, pero se avisa tras 30 días.

### Contenido de Analíticas (día a día / semana a semana)
1. **Resumen**: nivel + barra de XP, racha actual/mejor, congeladores, racha semanal.
2. **Anillos de la semana** (RadialBar): entrenos x/3, corridas x/2, con comparación vs. semana anterior.
3. **Minutos activos por día** (barras, últimos 7 días) y **por semana** (últimas 8–12 semanas), apilados por tipo.
4. **Km corridos por semana** (barras) y **ritmo (min/km)** en el tiempo (línea, solo corridas con km).
5. **Calorías estimadas** por semana (área).
6. **Calendario de constancia** (mapa de calor mensual, grilla propia; Recharts no tiene heatmap).
7. **Distribución por tipo** (dona): entrenos vs. corridas (cinta/calle) vs. descanso activo.
8. **Sensación** (tendencia de 1–5) en el tiempo.
9. **Récords personales**: mejor racha, corrida más larga, mayor km, más rondas AMRAP, semana más activa.
10. **Logros**: galería con bloqueados/desbloqueados.
11. **Desafíos**: desafío de la semana con progreso e historial de completados; % de misiones diarias cumplidas por semana.
12. **Vacaciones**: períodos marcados en el calendario y en los gráficos semanales (la semana pausada no se muestra como "fallida").
13. **Cuenta**: usuario conectado, peso, cerrar sesión, modo vacaciones.
Selector de rango: Semana / Mes / Todo. Estados vacíos motivadores (nada de gráficos en blanco).

---

## Sub-tareas

### 1. Supabase: proyecto, esquema, RLS y cliente
- **Intención**: tener backend gratuito listo y seguro, reutilizando el proyecto y los usuarios de PlanDental.
- **Resultados esperados**: tablas `cf_profiles`, `cf_activities`, `cf_achievements`, `cf_vacations` con RLS aplicadas en el proyecto compartido; PlanDental verificado sin cambios; cliente con login usuario + contraseña; credenciales fuera del repo.
- **Todo**:
  1. Crear script SQL versionado (`supabase/schema.sql`) con tablas, índices (`user_id, occurred_on`) y políticas RLS.
  2. Documentar el proyecto compartido, el aislamiento `cf_*` y cómo aplicar el esquema con la CLI.
  3. Agregar `@supabase/supabase-js` (última versión estable, verificar mantenimiento/CVEs).
  4. Crear `.env.example` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`); confirmar que `.env*` esté en `.gitignore`.
  5. Crear cliente Supabase con `signIn` / `signOut` / `getSession` (usuario + contraseña, mismo mapeo que PlanDental).
  6. Tipos TypeScript de filas y mapeo a modelo de dominio.
- **Contexto relevante**: [`package.json`](package.json), [`.gitignore`](.gitignore), [`vite.config.ts`](vite.config.ts).
- **Notas**: el anon key es público por diseño; la protección es RLS. El rol `anon` no tiene permisos sobre `cf_*`. El login anónimo sigue deshabilitado (habilitarlo rompería el trigger de alta de usuarios de PlanDental y expondría sus tablas con políticas abiertas a cualquier usuario autenticado).
- **Status**: `[x] done`
- **Artefactos y contexto para Sub-tareas 2 y 3**:
  - `supabase/schema.sql`: aplicado en el proyecto compartido. Tablas `cf_profiles`, `cf_activities`, `cf_achievements`, `cf_vacations`, índices, trigger `cf_set_updated_at` y RLS. `day_id` es texto libre (hasta 64 caracteres) para soportar rutinas por usuario.
  - `supabase/README.md`: proyecto compartido, aislamiento, aplicación del esquema y variables de entorno.
  - `.env` local creado (ignorado por git) con URL y anon key.
  - `.env.example`: Plantilla de variables (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`).
  - `src/types/database.ts`: Tipos TypeScript de tablas PostgreSQL (`ProfileRow`, `ActivityRow`, `AchievementRow`, `VacationRow`, `Database`).
  - `src/types/gamification.ts`: Modelos de dominio (`Activity`, `UserProfile`, `AchievementUnlock`, `VacationPeriod`) y funciones de mapeo bidireccional (`toDomainActivity`, `toDbActivity`, `toDomainProfile`, `toDbProfile`, `toDomainAchievement`, `toDbAchievement`, `toDomainVacation`, `toDbVacation`).
  - `src/lib/supabase.ts`: cliente `supabase` tipado, `isSupabaseConfigured()`, `signIn(username, password)`, `signOut()`, `getSession()`, `getCurrentUserId()`, `getAuthProfile(session)` (lectura de `public.profiles`, solo lectura) y `onAuthChange()`. Ya no existe `ensureSession()` ni login anónimo. Tolerante a variables no definidas (cliente null).
  - `src/types/database.ts`: el tipo `Database` usa las tablas `cf_*`.

### 2. Motor de gamificación (funciones puras) + tests
- **Intención**: concentrar toda la lógica de juego en código puro, testeable y ajustable.
- **Resultados esperados**: dado `activities[]` + `hoy` + `perfil`, se obtiene racha (con congeladores), racha semanal, XP, nivel, progreso de semana, calorías y logros desbloqueados.
- **Todo**:
  1. Definir tipos de dominio (`Activity`, `Profile`, `Achievement`) en `src/types/`.
  2. Archivo de configuración de reglas (XP, niveles, metas, MET, umbrales de logros).
  3. Funciones: `estimateCalories`, `computeXp`, `levelFromXp`, `computeStreak` (congeladores deterministas, ignorando días de vacaciones), `weekProgress`, `weeklyStreak` (semanas pausadas por vacaciones no rompen), `evaluateAchievements`, `pickCoachMessage`, `pickWeeklyChallenge` (determinista por semana ISO), `pickDailyMissions`, `evaluateChallenge` / `evaluateMissions`, `isComebackWindow` (días posteriores a vacaciones), `mascotStage` (según nivel).
  4. Manejo cuidadoso de fechas locales (`occurred_on` como fecha local, semana lunes–domingo, zona horaria de Juli).
  5. Agregar Vitest (devDependency) y tests de bordes: cambio de semana, congelador consumido/ganado, múltiples actividades en un día, huecos largos, vacaciones que cruzan semanas/meses, vacaciones abiertas (sin fin), ventana de regreso, desafío semanal determinista, misión imposible reemplazada.
- **Contexto relevante**: [`src/types/workout.ts`](src/types/workout.ts), [`src/utils/time.ts`](src/utils/time.ts); nueva carpeta `src/gamification/`.
- **Status**: `[x] done`
- **Artefactos y contexto para Sub-tareas 3 a 6** (125 tests pasan con `npm test`; `npm run build` pasa):
  - Todo el motor vive en `src/gamification/` y son funciones puras: reciben un `GameContext` `{ activities, vacations, today, weightKg?, displayName? }` y no guardan nada. XP, rachas, logros, desafíos y misiones se **derivan** del historial, así que todos los dispositivos del usuario coinciden.
  - **Punto de entrada**: `computeGameSummary(ctx)` devuelve `{ xp, level, mascot, streak, weekly, week, challenge, missions, achievements, vacation, comeback, coach }`. Antes de calcular descarta actividades con fecha inválida o futura y vacaciones inválidas. Usar `todayKey()` para `today` (fecha local).
  - **Al registrar una actividad**: `computeActivityXp(ctx, activity)` da el `xpEarned` a guardar (incluye ×1.5 de regreso) y `estimateCalories(activity, weightKg)` da `caloriesKcal` (null si falta el peso). El XP total mostrado sale de `computeXp`, no de la suma de `xpEarned`.
  - **Logros**: `newlyUnlocked(ctx, idsYaGuardados)` devuelve los recién desbloqueados para celebrarlos una sola vez y persistirlos en `cf_achievements`.
  - **Analíticas**: `challengeHistory(ctx)` (un desafío por semana), `computeWeeklyStreak(ctx).weeks` (una `WeekProgress` por semana, con minutos, km y días activos) y `computeStreak(ctx).milestones/freezesUsedOn`.
  - **Fechas**: `DateKey` = `YYYY-MM-DD` en hora local; las semanas van de lunes a domingo. Helpers en `dates.ts` (`todayKey`, `weekStart`, `weekEnd`, `addDays`, `eachDay`, `isoWeek`).
  - **Vacaciones**: `startOn` y `endOn` son inclusivos y `endOn = null` significa activas. **Convención para la UI**: al terminar las vacaciones, guardar `endOn = ayer` (el día de vuelta ya cuenta como día normal y es el día 1 de "¡Hay que recuperar!").
  - **Descanso activo**: para el XP solo suma el primero de cada día, aunque se registren varios.
  - **Cambios de comportamiento durante los tests**: el coach ya no tiene la regla `keep_going` (era inalcanzable porque `atRisk` responde antes); "necesita corrida" concuerda en plural (`te faltan 2 corridas`).
  - Los tests están en `src/gamification/__tests__/` (`helpers.ts` trae `workout`, `run`, `rest`, `vacation`, `ctx`). Se compilan con `tsc` en el build.

### 3. Capa de datos local-first y sincronización
- **Intención**: guardar siempre, incluso sin señal, y reflejarlo en Supabase cuando haya conexión.
- **Resultados esperados**: al terminar un día se crea una `activity` local inmediata y se sube a Supabase; si falla, queda en cola y reintenta (al abrir, al volver `online`). Sin duplicados (id idempotente). Historial se hidrata desde Supabase en otro dispositivo.
- **Todo**:
  1. Nuevo hook de actividades (reemplaza/absorbe la parte de logs de `useWorkoutStorage`), con cache y cola en localStorage.
  2. Sincronización (upsert por `id`) y carga inicial desde Supabase.
  3. Corregir `tipoBloque` real al registrar bloques.
  4. Derivar "día completado" y "bloque completado" desde actividades de la semana/día actual (corrige "COMPLETADO HOY" permanente); migrar/ignorar claves antiguas de localStorage sin romper.
  5. Definir fin de día = todos los bloques completados; en ese momento crear la `activity` `workout_day` (duración sumada, rondas, bloques).
  6. Indicador discreto de estado de sync (pendiente/sincronizado).
- **Contexto relevante**: [`src/hooks/useWorkoutStorage.ts`](src/hooks/useWorkoutStorage.ts), [`src/App.tsx`](src/App.tsx:54) (`handleBlockCompleted`), [`src/components/DayCard.tsx`](src/components/DayCard.tsx), [`src/views/DayDetailView.tsx`](src/views/DayDetailView.tsx).
- **Status**: `[x] done`
- **Artefactos y contexto para Sub-tareas 4 a 6** (137 tests pasan con `npm test`; `npm run build` pasa):
  - `src/hooks/useActivities.ts`: `useActivities(userId)` → `{ activities, addActivity(draft, { weightKg?, vacations? }), syncStatus }`. `addActivity` genera el UUID en el cliente, calcula `xpEarned` (`computeActivityXp`) y `caloriesKcal` (`estimateCalories`), guarda **al instante** en localStorage y sube en segundo plano; devuelve la `Activity` guardada. Para "Hoy corrí" (sub-tarea 4) hay que pasarle `weightKg` y `vacations` para que XP y calorías sean correctos. `syncStatus`: `'synced' | 'syncing' | 'pending' | 'offline'`.
  - **Sincronización**: primero sube las pendientes (upsert por `id` con `ignoreDuplicates`, así reintentar nunca duplica) y después descarga todo el historial (paginado de a 1000) y lo fusiona (`mergeRemoteActivities`: gana lo local pendiente, el resto sale del servidor). Se dispara al abrir, al volver `online`, al volver a la pestaña y cada 60 s mientras haya pendientes. Si falla, queda en cola sin perder nada.
  - `src/lib/activitiesApi.ts` (`fetchAllActivities`, `pushActivity`), `src/utils/activityCache.ts` (claves `cardiofeliz_<userId>_activities` y `_activities_pending`) y `src/utils/activitySync.ts` (`sortActivities`, `mergeRemoteActivities`, `newActivityId`).
  - `src/hooks/useBlockProgress.ts` + `src/utils/workoutDay.ts`: los bloques completados **de hoy** se guardan con tipo real (`tipoBloque` corregido, ya no es siempre `EMOM`), duración y rondas; al cambiar la fecha se descartan. El día termina cuando **todos** los bloques están completados (`isDayFinished`) y en ese momento se crea una sola `workout_day` (`buildWorkoutDayActivity`: duración sumada, rondas, bloques e inicio). Si el mismo día de rutina se repite hoy, no se crea una segunda actividad.
  - `weekCompletedDays` deriva "completado" de las actividades de la semana (lunes a domingo): `DayCard` muestra "COMPLETADO HOY" o "COMPLETADO ESTA SEMANA" (prop `completion`). Corrige el "COMPLETADO HOY" permanente.
  - **Eliminado**: `useWorkoutStorage` y `WorkoutSessionLog`. Las claves viejas `completed_blocks`, `completed_days` y `workout_logs` quedan en localStorage sin usarse (no se migran: no representaban actividades con fecha). `migrateLegacyStorage` sigue moviéndolas al usuario, sin efecto funcional.
  - `Header` recibe `syncStatus` y muestra un ícono de nube discreto (con `aria-label`); amarillo si hay pendientes o no hay conexión.
  - **Pendiente de la sub-tarea 4/5**: las vacaciones y el peso aún no se cargan desde Supabase (`addActivity` los recibe como opciones; hasta que existan, el XP de regreso y las calorías no se aplican a los entrenamientos). La capa de `cf_vacations`, `cf_profiles.weight_kg` y `cf_achievements` se resuelve en las sub-tareas 4, 5 y 5b.
  - No verificado: sincronización contra Supabase con una sesión real (no hay credenciales disponibles) ni el modo offline → online en dispositivo.
  - Tests nuevos en `src/gamification/__tests__/data-layer.test.ts` (progreso de bloques, armado del día, "completado" semanal, merge de sync y UUID).

### 4. Perfil (peso) y flujo "Hoy corrí"
- **Intención**: registrar corridas con mínima fricción y habilitar estimación de calorías.
- **Resultados esperados**: botón "Hoy corrí" visible en Home; un toque guarda 30 min; luego se ofrece "Ajustar" (minutos, km opcional, cinta/calle, sensación, fecha para registrar "ayer"). Peso pedido una sola vez (primer uso que lo necesite) y editable luego.
- **Todo**:
  1. Componente/bottom sheet de peso (una vez) y persistencia en `profiles`.
  2. Botón "Hoy corrí" en `HomeView` (destacado, con copy que recuerde la meta de 2 corridas/semana).
  3. Sheet de ajuste con valores por defecto, validación de rangos (minutos, km, fecha no futura).
  4. Guardado vía capa de datos; celebración (XP ganado, racha, confeti existente) y posible desbloqueo de logro.
  5. Acción de "descanso activo" de 1 toque (caminata/movilidad) para sostener la racha en días libres.
  6. Evitar doble registro accidental (deshacer breve / confirmación liviana).
- **Contexto relevante**: [`src/views/HomeView.tsx`](src/views/HomeView.tsx), [`src/components/WorkoutCompleteModal.tsx`](src/components/WorkoutCompleteModal.tsx) (patrón de modal + `canvas-confetti`), estilo Tailwind existente (`cardio-primary`, `surface-*`).
- **Status**: `[ ] pending`

### 5. UI de gamificación en Home y cierre de día
- **Intención**: que abrir la app muestre progreso y motivos para volver.
- **Resultados esperados**: en Home: racha (con congeladores), nivel/XP, anillos de la semana y mensaje del coach. Al terminar el día: pantalla de celebración con XP ganado, racha, avance de meta semanal y logros nuevos.
- **Todo**:
  1. Componentes: chip de racha, barra de nivel/XP, anillos semanales compactos, tarjeta del coach (descartable, una vez por día).
  2. Extender el cierre de día (modal existente o variante) con resumen de XP/racha/logros.
  3. Toasts de logro desbloqueado y subida de nivel.
  4. Persistir en `achievements` los desbloqueos y evitar re-celebrar.
  5. Respetar `prefers-reduced-motion` y reutilizar `soundEngine.playVictoryFanfare` respetando mute.
- **Contexto relevante**: [`src/views/HomeView.tsx`](src/views/HomeView.tsx), [`src/components/WorkoutCompleteModal.tsx`](src/components/WorkoutCompleteModal.tsx), [`src/utils/audio.ts`](src/utils/audio.ts), [`src/hooks/useAudioBeeps.ts`](src/hooks/useAudioBeeps.ts).
- **Status**: `[ ] pending`

### 5b. Desafíos semanales, misiones diarias, mascota y modo vacaciones (UI + datos)
- **Intención**: sumar los loops de retorno diario/semanal y la personalidad del coach.
- **Resultados esperados**: en Home, tarjeta de misiones del día (con XP extra y bonus por completar todas) y tarjeta del desafío semanal con progreso; mascota que evoluciona con el nivel y es la voz de los mensajes; toggle de vacaciones que pausa racha/metas y, al volver, activa el modo "¡Hay que recuperar!" por los primeros días.
- **Todo**:
  1. Catálogos de desafíos y misiones en el archivo de configuración (reglas del sub-tarea 2), con validación de factibilidad.
  2. Tarjetas de misiones y de desafío; XP extra mostrado al cumplirse (cálculo derivado, sin tabla de reclamos).
  3. Mascota SVG con etapas por nivel y estados de ánimo; integrarla a la tarjeta del coach y al cierre de día.
  4. Modo vacaciones: alta/baja en la tabla `vacations` (local-first, misma cola de sync), estado visible en Home, ocultar misiones/desafíos mientras esté activo, aviso tras 30 días.
  5. Modo "¡Hay que recuperar!" al volver: mensajes del coach, misión de vuelta suave y bonus de regreso (a validar con el usuario).
  6. Evitar activar/desactivar vacaciones por error (confirmación liviana); permitir corregir fechas.
- **Contexto relevante**: [`src/views/HomeView.tsx`](src/views/HomeView.tsx), motor en `src/gamification/`, capa de datos del sub-tarea 3.
- **Status**: `[ ] pending`

### 6. Vista de Analíticas + ícono en el header
- **Intención**: dar a Juli una sección de progreso que motive día tras día y semana tras semana.
- **Resultados esperados**: ícono `BarChart3` en el header a la izquierda del botón de silenciar abre la vista `analytics`; gráficos y estadísticas del contenido definido arriba, con selector Semana/Mes/Todo y estados vacíos.
- **Todo**:
  1. Agregar `recharts` (última versión estable, verificar compatibilidad con React 18 y mantenimiento).
  2. Header: nuevo prop `onAnalyticsClick` y botón con mismo estilo que el de sonido; mantener orden: indicador de pantalla → analíticas → silenciar.
  3. `ViewMode` + `'analytics'` en `App.tsx`, con botón/flujo de volver.
  4. Selectores/agregaciones de datos para cada gráfico (reutilizar el motor del sub-tarea 2).
  5. Componentes de gráficos con tema oscuro OLED y colores del tema; accesibles (etiquetas, no depender solo del color).
  6. Heatmap mensual como grilla propia; anillos con RadialBar.
  7. Sección de récords, logros, desafíos (historial), vacaciones marcadas en calendario/semanas y cuenta (peso, modo vacaciones).
  8. Verificar rendimiento y que Recharts no infle el bundle inicial (carga diferida de la vista).
- **Contexto relevante**: [`src/components/Header.tsx`](src/components/Header.tsx), [`src/App.tsx`](src/App.tsx), [`tailwind.config.js`](tailwind.config.js).
- **Status**: `[ ] pending`

### 7. Login compartido con PlanDental y sesión (hacer ANTES de la sub-tarea 3)
- **Intención**: reutilizar la gestión de usuarios de PlanDental y dejar la app lista para multiusuario.
- **Resultados esperados**: pantalla de login (usuario + contraseña) con el mismo comportamiento que PlanDental; la sesión persiste entre recargas; cierre de sesión desde Analíticas > Cuenta; el nombre mostrado ("Hola Juli") sale del usuario conectado.
- **Todo**:
  1. Hook/contexto de sesión basado en `onAuthChange` (una única fuente de verdad, sin parpadeo de la pantalla de login al recargar, igual que en PlanDental).
  2. Pantalla de login con estilo de la app y mensajes de error genéricos; sin loguear credenciales.
  3. Decisión tomada: se exige login, como PlanDental (la pantalla de login aparece siempre que no hay sesión).
  4. Namespacing de las claves de localStorage por `user_id` para que dos usuarios en el mismo dispositivo no mezclen datos; migrar los datos locales existentes al primer usuario que inicie sesión.
  5. Nombre para mostrar desde `getAuthProfile` / `cf_profiles.display_name` (reemplaza `rutina.usuario`).
  6. Alta de usuarios: se gestiona desde PlanDental (no se duplica).
- **Contexto relevante**: [`src/lib/supabase.ts`](src/lib/supabase.ts), [`src/App.tsx`](src/App.tsx), referencia: `../plandental/js/app.js` (`onAuthStateChange`) y `../plandental/js/storage.js` (`signIn`).
- **Fuera de alcance por ahora**: rutinas distintas por usuario (hoy `rutina.json` es único; el modelo de datos ya lo permite con `day_id` libre).
- **Status**: `[x] done`
- **Artefactos y contexto para las sub-tareas siguientes**:
  - `src/auth/AuthContext.tsx`: `AuthProvider`, `useAuthState()` y `useCurrentUser()` → `{ userId, username, displayName, signOut }`. `displayName` sale de `cf_profiles.display_name` y, si no existe, del usuario con la primera letra en mayúscula. La sesión se resuelve solo con `onAuthStateChange`.
  - `src/components/AuthGate.tsx`: pantalla de carga → login (`src/views/LoginView.tsx`) → app. Remonta `<App />` al cambiar de usuario (`key={userId}`). Si faltan las variables de entorno, muestra "Servicio no configurado".
  - `src/main.tsx` envuelve `<App />` con `AuthProvider` y `AuthGate`; dentro de `App`, `useCurrentUser()` siempre tiene sesión.
  - `src/utils/userStorage.ts`: `userStorageKey(userId, name)` (claves `cardiofeliz_<userId>_<name>`) y `migrateLegacyStorage(userId)` (mueve una sola vez los datos locales viejos al primer usuario que ingresa). `useWorkoutStorage(userId)` ya usa estas claves. La clave de silencio (`cardiofeliz_muted`) sigue siendo por dispositivo.
  - `Header`: muestra el nombre del usuario y un botón de cerrar sesión con confirmación (provisorio; el plan lo ubica en Analíticas > Cuenta, sub-tarea 6, y ahí se puede mover).
  - `public/sw.js` (cache `v2`): ya no intercepta pedidos a otros orígenes, así que los datos de Supabase nunca salen de la caché.
  - `src/types/database.ts`: las filas pasaron de `interface` a `type` y `Database` incluye `Relationships`, `Views`, `Functions`, `Enums` y `CompositeTypes`; supabase-js los exige para inferir los tipos.
  - Verificado: `npm run build` limpio; sin sesión aparece el login; credenciales inválidas muestran "Usuario o contraseña incorrectos.".
  - No verificado: inicio de sesión con credenciales reales (no tengo la contraseña de ningún usuario).

### 8. PWA, documentación y validación final
- **Intención**: que todo funcione en producción/PWA y quede documentado.
- **Resultados esperados**: Service Worker no cachea llamadas a Supabase; build limpio; README con setup.
- **Todo**:
  1. Ajustar [`public/sw.js`](public/sw.js) para ignorar requests al dominio de Supabase; subir versión de cache.
  2. README: variables de entorno, SQL, pasos de Supabase, nota sobre pausa del free tier.
  3. Ejecutar `npm run build` (tsc + vite) y tests del motor; revisar bundle.
  4. Prueba manual: terminar día, "Hoy corrí" rápido y ajustado, modo offline → online, cambio de semana, abrir en segundo dispositivo iniciando sesión con el mismo usuario.
- **Status**: `[ ] pending`

---

## Fuera de alcance
- Push notifications (requieren servidor/web push y permisos iOS).
- Ranking/amigos/social.
- Integraciones con wearables o GPS.
- Cambios al contenido de la rutina (`rutina.json`).

## Orden recomendado
1 → 2 → 7 (login) → 3 → 4 → 5 → 5b → 6 → 8 (cada sub-tarea revisable por separado; el login va antes de la capa de datos porque las filas se guardan por usuario).
