# Plan: rutina editable desde la app (CardioFeliz)

## Resumen

Hoy la rutina es un archivo estático ([`src/data/rutina.json`](src/data/rutina.json)) que solo se importa en [`src/App.tsx`](src/App.tsx:2). El objetivo es:

1. Reemplazar ese archivo por la rutina nueva. Pasa a ser la **rutina por default**.
2. Dejar que cada usuario edite su propia rutina desde una pantalla aparte ("Mi rutina"). Se llega con un botón al final de Home, así el uso diario no cambia.
3. Guardar la rutina por usuario en Supabase, con caché local para que funcione offline.
4. Hacer que los tiempos editados tengan efecto real, haciendo configurables los timers.
5. Guardar el progreso de bloques por **id estable de bloque**, no por índice. Así editar la rutina no borra el progreso de hoy.

### Decisiones confirmadas

| Tema | Decisión |
|---|---|
| Almacenamiento | Tabla nueva `cf_routines` en Supabase, una fila por usuario, con RLS y caché local. Hay que correr un SQL de migración. |
| Alcance del editor | Completo. Crear, borrar y reordenar días y bloques. Editar nombre, ubicación, calentamiento, tipo, tiempos y ejercicios. También `objetivo` y `edad`. Importar y exportar JSON. Restaurar la rutina original. |
| Tipos nuevos | `DENSITY` usa el timer de Triserie. `HIIT_INTERVALS` usa el timer de Finisher. |
| Progreso | Por id estable de bloque. No se borra al editar. |
| Edición | Con borrador. Los cambios se aplican solo al tocar "Guardar". |
| Pasos por repeticiones | Pasos como "20 Russian Twists" avanzan con botón "Listo". Los pasos con `segundos` o con "Descanso" corren solos. |
| Rutinas | Por usuario, no se comparten. Un usuario sin rutina guardada recibe la rutina default. |
| Fuera de alcance | Editar `usuario`: el nombre sigue saliendo del login. Compartir rutinas. |

### Esquema propuesto

Los campos nuevos son opcionales. Si faltan, valen los defaults de hoy.

- **Bloque:** `id` (estable), `rondas`, `descanso_seg`, `trabajo_seg` y `descanso_tabata_seg` (para Tabata).
- **Ejercicio de Finisher/HIIT:** `segundos` opcional. Sin `segundos`, el paso es manual.
- **Día:** el `id` actual no cambia nunca, aunque se renombre el día. Los días nuevos reciben un id generado.
- **Rutinas existentes sin `id` de bloque:** una función de normalización les asigna ids al cargarlas.

### Cómo queda cada bloque de la rutina nueva

| Bloque | Tipo | Configuración |
|---|---|---|
| Día 1 A | `EMOM` | 16 min, 4 ejercicios. Sin cambios. |
| Día 1 B | `HIIT_INTERVALS` | 4 rondas de 3 pasos de 60 s, con `trabajo_seg: 40`. Minuto 1: 40 s de trabajo (SkiErg/Assault Bike) + 20 s de transición. Minuto 2: 40 s de trabajo (caminata inclinada) + 20 s de transición. Minuto 3: descanso de 60 s. Los minutos 4 a 12 repiten 1, 2 y 3. Suma 12 min. |
| Día 1 y Día 2 Finisher | `FINISHER` | 3 rondas. Día 1 usa pasos por repeticiones más 30 s de descanso. Día 2 usa pasos de 30 s. |
| Día 2 A | `DENSITY` | 4 rondas, 4 ejercicios, 45 s de descanso entre rondas. |
| Día 2 B | `AMRAP` | 12 min. Sin cambios. |
| Día 3 A | `AMRAP` | 15 min. Sin cambios. |
| Día 3 B | `EMOM` | 12 min. Sin cambios. |
| Día 3 Finisher | `TABATA` | 8 rondas de 20 s trabajo y 10 s descanso. Sin cambios. |

Al reemplazar el JSON también se corrige la clave `"calentami  ento"` (con espacios) que hoy deja al Día 1 sin calentamiento.

### Flujo de pantallas

- **Home:** botón "Mi rutina" al final.
- **Mi rutina:** objetivo y edad, lista de días con reordenar, borrar y agregar, más importar, exportar y restaurar.
- **Editar día:** nombre, ubicación, calentamiento y lista de bloques.
- **Editar bloque:** tipo, nombre, campos de tiempo y rondas según el tipo, y lista de ejercicios.
- **Guardar:** aplica los cambios y los sincroniza.
- **Cancelar o volver con cambios sin guardar:** pide confirmación.

---

## Sub-tarea 1: Modelo de datos, validación y rutina por default

- **Status:** `[x] done`
- **Intent:** definir el esquema nuevo, la rutina por default y las funciones puras de normalización y validación. El resto de las sub-tareas se apoya en esto.
- **Expected Outcomes:**
  - Los tipos admiten `DENSITY` y `HIIT_INTERVALS`, los ids de bloque y los campos configurables.
  - [`rutina.json`](src/data/rutina.json) contiene la rutina nueva con ids de bloque y sin el typo de `calentamiento`.
  - Existe una función que carga cualquier rutina (guardada o importada) y le asigna ids faltantes. Existe otra que valida una rutina y devuelve errores legibles.
- **Todo List:**
  1. Extender [`src/types/workout.ts`](src/types/workout.ts): agregar `id` a `BloqueBase`, los tipos `DENSITY` y `HIIT_INTERVALS`, los campos `rondas`, `descanso_seg`, `trabajo_seg`, `descanso_tabata_seg` y `segundos` por ejercicio. Mantener `TRISERIE` por compatibilidad con rutinas ya guardadas.
  2. Reemplazar [`src/data/rutina.json`](src/data/rutina.json) por la rutina nueva. Incluir ids de bloque, `rondas` y `segundos` según la tabla de arriba.
  3. Crear un módulo de utilidades de rutina (por ejemplo `src/utils/routine.ts`) con:
     - Normalización: asigna ids de bloque faltantes y completa defaults.
     - Validación con allowlist de tipos. Comprueba que los números sean enteros positivos y acotados, que los textos tengan largo máximo, que los ids de día sean únicos y que haya un tope razonable de días, bloques y ejercicios.
     - Generador de ids para días y bloques nuevos.
     - Fábrica de bloque nuevo con defaults por tipo.
  4. En [`src/App.tsx`](src/App.tsx) dejar de castear el JSON directo. Usar la rutina normalizada, por ahora todavía sin persistencia.
- **Relevant Context:** [`src/types/workout.ts`](src/types/workout.ts), [`src/data/rutina.json`](src/data/rutina.json), [`src/App.tsx`](src/App.tsx:33). Ver cómo [`src/utils/workoutDay.ts`](src/utils/workoutDay.ts) y [`src/components/DayCard.tsx`](src/components/DayCard.tsx) usan `tipo`.

### Notas de implementación (contexto para sub-tareas siguientes)

- **`BloqueDensity`** y **`BloqueHiitIntervals`** son interfaces propias en [`src/types/workout.ts`](src/types/workout.ts). `DENSITY` usa el mismo timer que `TRISERIE`; `HIIT_INTERVALS` usa el mismo timer que `FINISHER`. El enrutamiento en `ActiveWorkoutView` se dejó para la Sub-tarea 3.
- **`HIIT_INTERVALS` Día 1 B:** modelado como 4 rondas de 3 pasos de 60 s (`segundos: 60` cada uno) → 3 × 60 s × 4 rondas = 720 s = 12 min. El bloque tiene `trabajo_seg: 40`: en cada paso con `segundos` mayor que `trabajo_seg`, el timer muestra primero la fase de trabajo (`trabajo_seg`) y después la fase de transición (`segundos - trabajo_seg`), con aviso sonoro y color distinto en cada una. El `detalle` ya no repite los tiempos. El tercer paso es "Descanso total" (60 s) y es todo descanso: los pasos cuyo `detalle` contiene "descanso" no se dividen. El timer de Finisher/HIIT implementa esto en la Sub-tarea 3.
- **`EjercicioGenerico`** tiene ahora el campo opcional `segundos?: number`. Los pasos sin `segundos` y sin "Descanso" en el detalle avanzan con botón "Listo" (lógica del timer, Sub-tarea 3).
- **`BloqueBase`** tiene `id?: string` más `rondas`, `descanso_seg`, `trabajo_seg` y `descanso_tabata_seg` opcionales. Las interfaces de bloque específicas los heredan.
- **Normalización:** [`src/utils/routine.ts`](src/utils/routine.ts) → `normalizeRutina` asigna ids de bloque faltantes sin mutar el original. `App.tsx` ya la usa.
- **Validación:** `validateRutina` recibe `unknown`, usa allowlist de tipos, enteros acotados, textos con largo máximo, ids de día únicos y topes de días/bloques/ejercicios. Devuelve `{ valid, errors }` con mensajes en español.
- **Tests:** 22 casos nuevos en [`src/utils/__tests__/routine.test.ts`](src/utils/__tests__/routine.test.ts). Todos los tests existentes siguen pasando (182 total).
- **Build y typecheck:** pasan sin errores ni warnings nuevos.
- **`BlockCard`/`DayCard`/`ActiveWorkoutView`** no se modificaron; los tipos nuevos caen en el `default` de los switches de estilos existentes, sin romper la compilación. Los badges y el enrutamiento de timer para `DENSITY` y `HIIT_INTERVALS` quedan para la Sub-tarea 3.

## Sub-tarea 2: Progreso de bloques por id estable

- **Status:** `[x] done`
- **Intent:** que editar, reordenar, agregar o borrar bloques no corrompa ni borre el progreso del día.
- **Expected Outcomes:**
  - El progreso de hoy se indexa por `{diaId, bloque.id}`.
  - El progreso que ya está en localStorage con claves por índice (`dia_X_bloque_N`) se convierte una vez al formato nuevo, usando la rutina vigente. Nada se pierde.
  - `isDayFinished` y `buildWorkoutDayActivity` funcionan con ids. Un día con bloques agregados o borrados se evalúa bien.
  - El historial de actividades (`dayId`) no se rompe si se borra o renombra un día.
- **Todo List:**
  1. Cambiar `blockKey` en [`src/utils/workoutDay.ts`](src/utils/workoutDay.ts:22) para usar el id del bloque.
  2. Ajustar `isDayFinished` y `buildWorkoutDayActivity` para recorrer los bloques por id.
  3. Ajustar `recordBlock` en [`src/hooks/useBlockProgress.ts`](src/hooks/useBlockProgress.ts) para recibir el bloque y no el índice.
  4. Agregar la conversión de claves viejas por índice a claves por id al cargar el progreso.
  5. Actualizar [`src/views/DayDetailView.tsx`](src/views/DayDetailView.tsx:61), que arma la clave a mano, y los handlers de [`src/App.tsx`](src/App.tsx:93) (`activeBlockIndex`). La navegación "bloque siguiente" sigue usando el orden en la rutina.
  6. Guardar el día seleccionado en `App` por id y no como objeto. Así, si la rutina cambia por una sincronización, no queda una copia vieja.
  7. Revisar [`src/components/WorkoutCompleteModal.tsx`](src/components/WorkoutCompleteModal.tsx) y [`src/components/DayCard.tsx`](src/components/DayCard.tsx), que usan `dayId` o `bloques`.
  8. Actualizar los tests existentes en [`src/gamification/__tests__/data-layer.test.ts`](src/gamification/__tests__/data-layer.test.ts) y agregar tests de la conversión.
- **Relevant Context:** [`src/utils/workoutDay.ts`](src/utils/workoutDay.ts), [`src/hooks/useBlockProgress.ts`](src/hooks/useBlockProgress.ts), [`src/views/DayDetailView.tsx`](src/views/DayDetailView.tsx), [`src/App.tsx`](src/App.tsx), [`src/gamification/__tests__/data-layer.test.ts`](src/gamification/__tests__/data-layer.test.ts).

### Notas de implementación (contexto para sub-tareas siguientes)

- **Clave de progreso:** `blockKey(diaId, blockId)` devuelve `` `${diaId}::${blockId}` `` (ver [`workoutDay.ts`](src/utils/workoutDay.ts)). Se usa `::` para que no se confunda con las claves viejas `dia_X_bloque_N`. Un bloque sin `id` nunca cuenta como completado y `recordBlock` lo ignora; `normalizeRutina` garantiza que siempre haya id.
- **Migración:** `migrateBlockProgress(progress, rutina)` es pura e idempotente. Convierte `dia_X_bloque_N` a la clave por id según el orden de la rutina que se le pase. Las claves que no puede resolver (día borrado, índice fuera de rango) se conservan, y si la clave nueva ya existe, gana sobre la vieja. `useBlockProgress` la corre en la carga inicial (después de descartar lo que no es de hoy) y guarda el resultado en localStorage solo si algo cambió, así no vuelve a correr con efectos distintos.
- **Firma nueva del hook:** `useBlockProgress(userId, rutina)` y `recordBlock(diaId, bloque, durationSeconds, rounds?)`. La rutina solo se lee al montar. **Para la Sub-tarea 4:** cuando `useRoutine` cargue una rutina guardada de forma asíncrona, la migración habrá corrido contra la rutina default. Si el progreso de hoy tiene claves viejas por índice y la rutina del usuario es otra, esas claves quedan sin resolver (no se pierden, pero no se mapean). Es un caso muy acotado, porque el progreso se descarta cada día y solo existe con claves viejas el día del despliegue. Si se quiere cubrir, llamar `migrateBlockProgress` de nuevo cuando llegue la rutina remota.
- **`App`:** guarda `selectedDayId` y deriva `selectedDay` con `useMemo` desde la rutina vigente. `activeBlock` sigue siendo un objeto; `activeBlockIndex` ya no es estado, se deriva con `findIndex` por `bloque.id` en el orden actual de la rutina (da `-1` si el bloque ya no existe). `handleNextBlock` y `hasNextBlock` usan ese índice derivado. `rutina` ahora está memoizada con `useMemo` por `user.displayName`; **la Sub-tarea 4 debe reemplazar ese `useMemo` por la rutina de `useRoutine`** manteniendo `usuario: user.displayName`.
- **`DayDetailView`:** `onStartBlock` recibe solo el bloque. Usa `blockKey` y `key={bloque.id}`.
- **`WorkoutCompleteModal` y `DayCard`:** revisados, no usan `dayId` ni índices de bloque; no necesitaron cambios. `weekCompletedDays` indexa por `dayId` de las actividades, así que un día borrado o renombrado simplemente no coincide con ningún `DayCard`. Las vistas de analytics no leen `dayId`.
- **Tests:** [`data-layer.test.ts`](src/gamification/__tests__/data-layer.test.ts) actualizado a ids y con casos nuevos: bloques agregados, borrados, reordenados, bloque sin id y 6 casos de migración (conversión, idempotencia, claves no resolubles, prioridad de la clave nueva, no mutación, vacío). Total: 192 tests pasando, incluidos los de `routine.test.ts` con el JSON actualizado (HIIT Día 1 B con `trabajo_seg: 40`). `npm run build` (incluye `tsc`) pasa sin warnings. El proyecto no tiene script de lint.

## Sub-tarea 3: Timers configurables y tipos nuevos

- **Status:** `[x] done`
- **Intent:** que rondas, descansos y duraciones editados cambien lo que hace cada timer. También soportar los dos tipos nuevos.
- **Expected Outcomes:**
  - `TriserieTimer` y `DENSITY` toman `rondas` y `descanso_seg` del bloque. Los textos de botones y encabezados reflejan esos valores y ya no dicen "45s" o "4 rondas" fijos.
  - `FinisherTimer` y `HIIT_INTERVALS` toman `rondas` y `segundos` por paso. Los pasos sin `segundos` y que no son descanso avanzan con botón "Listo". Los pasos de descanso sin `segundos` usan un valor por defecto.
  - Si el bloque tiene `trabajo_seg` y un paso tiene `segundos` mayor, el paso se divide en fase de trabajo (`trabajo_seg`) y fase de transición (el resto), con cuenta regresiva, sonido y color propios. Los pasos de descanso no se dividen. Sin `trabajo_seg`, el paso corre entero como hoy. La progresión y el total de pasos cuentan cada fase.
  - `TabataTimer` toma rondas, trabajo y descanso del bloque. Con los defaults se comporta igual que hoy.
  - [`BlockCard`](src/components/BlockCard.tsx) y [`DayCard`](src/components/DayCard.tsx) muestran estilo y metadata correctos para los tipos nuevos.
  - `EMOM` y `AMRAP` siguen funcionando con las duraciones editadas. `EMOM` sigue ciclando ejercicios por minuto.
- **Todo List:**
  1. Leer config del bloque en [`TriserieTimer.tsx`](src/components/timers/TriserieTimer.tsx:23), con defaults de 4 rondas y 45 s. Actualizar los textos fijos.
  2. Reescribir el modelo de pasos de [`FinisherTimer.tsx`](src/components/timers/FinisherTimer.tsx:23) para admitir pasos con tiempo y pasos manuales. Actualizar progreso y textos ("Intervalo Activo 30s", "FINISHER CORE (3 Rondas)").
  3. Parametrizar [`TabataTimer.tsx`](src/components/timers/TabataTimer.tsx:25).
  4. Enrutar `DENSITY` y `HIIT_INTERVALS` en [`ActiveWorkoutView.tsx`](src/views/ActiveWorkoutView.tsx:86). Aceptar `TRISERIE` y `DENSITY` en el mismo timer, y `FINISHER` y `HIIT_INTERVALS` en el mismo timer.
  5. Agregar estilo de badge y `getBlockMeta` para los tipos nuevos en [`BlockCard.tsx`](src/components/BlockCard.tsx:19). Revisar los colores por tipo de `DayCard`.
  6. Verificar a mano cada timer con la rutina nueva: EMOM, HIIT, Finisher con repeticiones, Density y Tabata.
- **Relevant Context:** [`src/components/timers/`](src/components/timers), [`src/views/ActiveWorkoutView.tsx`](src/views/ActiveWorkoutView.tsx), [`src/components/BlockCard.tsx`](src/components/BlockCard.tsx), [`src/components/DayCard.tsx`](src/components/DayCard.tsx).

### Notas de implementación (contexto para sub-tareas siguientes)

- **Lógica pura:** [`src/utils/timerConfig.ts`](src/utils/timerConfig.ts) concentra la configuración y el secuenciado: `getTriserieConfig`, `getTabataConfig`, `getFinisherRounds`, `buildFinisherPhases`, `finisherProgress`, `finisherTotalSeconds`, `parseRestSeconds` e `isRestExercise`. Los timers y `BlockCard` la usan. Valores inválidos (no enteros, negativos) caen al default.
- **Defaults:** Triserie/Density 4 rondas y 45 s (`descanso_seg`, y si falta se parsea `descanso_entre_rondas` tipo "45 seg"; `descanso_seg: 0` es válido y salta el descanso). Tabata 8 / 20 s / 10 s. Finisher/HIIT 3 rondas; descanso sin `segundos` = 30 s.
- **Fases del Finisher/HIIT:** `buildFinisherPhases` devuelve una lista plana de fases (`WORK`, `TRANSITION`, `REST`, `MANUAL`) con ronda, índice de ejercicio y segundos. Un paso (no descanso) con `segundos > trabajo_seg` se divide en `WORK` + `TRANSITION`. HIIT Día 1 B da 20 fases y 720 s. Finisher Día 1 da 9 fases (6 manuales + 3 descansos de 30 s).
- **`FinisherTimer`:** reescrito sobre esa lista. Usa refs (`phaseIndexRef`, `secondsLeftRef`, `elapsedRef`) para que el `setInterval` no se reinicie en cada tick. En un paso manual el tiempo total corre pero no hay cuenta regresiva; aparece el botón "LISTO" (junto a un botón de pausa). "Terminar Bloque" usa `elapsedRef`. El contador muestra `fase actual/total de fases`. La barra pesa las fases por duración; un paso manual pesa 30 s (`MANUAL_PHASE_WEIGHT_SECONDS`). La transición se muestra en ámbar con `playRest`.
- **Tipos de props:** `TriserieTimer` acepta `BloqueTriserie | BloqueDensity`; `FinisherTimer` acepta `BloqueFinisher | BloqueHiitIntervals`. [`ActiveWorkoutView`](src/views/ActiveWorkoutView.tsx) enruta los tipos nuevos y pasa `key={bloque.id}` para reiniciar el estado del timer al cambiar de bloque.
- **`TabataTimer`:** lee la config del bloque; el encabezado (`TABATA (N Min)`) y la barra de progreso se calculan con esos valores.
- **`BlockCard`:** badges nuevos (`DENSITY` índigo, `HIIT_INTERVALS` rosa) y metadata con rondas/descanso (`4 Rondas • Descanso 45s`, `12 min • 4 Rondas`, `3 Rondas`). `DayCard` solo muestra `HIIT INTERVALS` sin guion bajo; no tiene colores por tipo. `WorkoutCompleteModal` no ramifica por tipo y no cambió.
- **`EMOM`/`AMRAP`:** sin cambios; ya leían `duracion_minutos` del bloque y `EMOM` cicla ejercicios por minuto.
- **Tests:** [`timerConfig.test.ts`](src/utils/__tests__/timerConfig.test.ts), 24 casos, algunos con la rutina real (HIIT Día 1 B, Finisher Día 1 y 2, Density Día 2 A, Tabata Día 3 C). Total: 216 tests pasando; `npm run build` (incluye `tsc`) sin errores ni warnings nuevos.
- **Verificación en navegador:** no se pudo. El login es con Supabase y no hay credenciales disponibles. El dev server arranca y la pantalla de login carga sin errores de consola (solo el warning previo del meta `apple-mobile-web-app-capable`). **Pendiente para la Sub-tarea 7:** probar a mano los timers en el celular (HIIT con transición, Finisher con "LISTO", Density, Tabata), incluido el sonido.
- **Para las Sub-tareas 5 y 6:** el editor de bloque puede usar `getTriserieConfig`, `getTabataConfig` y `buildFinisherPhases` para mostrar una vista previa de duración. El texto libre `estructura` de Tabata tiene prioridad en `BlockCard`; si el editor cambia `rondas`/`trabajo_seg`/`descanso_tabata_seg`, conviene regenerar o borrar `estructura` para que la metadata no quede desactualizada. Lo mismo pasa con `descanso_entre_rondas` (string legacy) frente a `descanso_seg`: `descanso_seg` manda.

## Sub-tarea 4: Persistencia por usuario (Supabase + caché local)

- **Status:** `[x] done`
- **Intent:** guardar la rutina de cada usuario, sincronizarla entre dispositivos y que funcione offline. Un usuario sin rutina guardada recibe la default.
- **Expected Outcomes:**
  - Tabla `cf_routines` creada con RLS por usuario y sin acceso para el rol `anon`. Sigue las reglas de aislamiento de [`supabase/schema.sql`](supabase/schema.sql).
  - Hook `useRoutine(userId, displayName)` que devuelve la rutina vigente (guardada o default), una función `saveRoutine` y una función `resetRoutine`.
  - Los cambios se guardan primero en local y se suben cuando hay conexión. Ante un conflicto gana la última escritura según `updated_at`.
  - `App` consume `useRoutine` en lugar del JSON directo.
- **Todo List:**
  1. Agregar a [`supabase/schema.sql`](supabase/schema.sql) la tabla `cf_routines` (`user_id` como clave primaria, `data jsonb`, `updated_at`). Incluir un `check` que limite el tamaño del JSON, trigger de `updated_at`, grants y políticas con el mismo patrón que las demás tablas. Entregar el SQL de migración para que el usuario lo ejecute.
  2. Agregar el tipo de fila en [`src/types/database.ts`](src/types/database.ts).
  3. Crear `src/lib/routineApi.ts` (fetch, upsert y delete) siguiendo el patrón de [`profileApi.ts`](src/lib/profileApi.ts).
  4. Crear `src/hooks/useRoutine.ts` con caché local y cola de pendientes, siguiendo el patrón de [`useVacations.ts`](src/hooks/useVacations.ts). La clave de storage va namespaceada por usuario con [`userStorageKey`](src/utils/userStorage.ts). Los datos se validan y normalizan al leerlos, sea de caché o de remoto.
  5. "Restaurar original" borra la fila del usuario y vuelve a la default.
  6. Conectar el hook en [`src/App.tsx`](src/App.tsx).
- **Relevant Context:** [`supabase/schema.sql`](supabase/schema.sql), [`supabase/migrations/cf_routines.sql`](supabase/migrations/cf_routines.sql), [`src/hooks/useVacations.ts`](src/hooks/useVacations.ts), [`src/lib/routineApi.ts`](src/lib/routineApi.ts), [`src/hooks/useRoutine.ts`](src/hooks/useRoutine.ts), [`src/utils/routineSync.ts`](src/utils/routineSync.ts).

### Notas de implementación (contexto para sub-tareas siguientes)

- **Migración SQL independiente:** ubicada en [`supabase/migrations/cf_routines.sql`](supabase/migrations/cf_routines.sql). Es idempotente y contiene solo los cambios de `cf_routines` (tabla con check de tamaño 500 KB, trigger de `updated_at`, permisos a `authenticated` y políticas RLS por usuario). El usuario debe ejecutarla en el SQL Editor de Supabase.
- **API del hook `useRoutine(userId, displayName)`:**
  - `rutina: RutinaData`: rutina vigente (personalizada o default). Garantiza `usuario === displayName`.
  - `isCustom: boolean`: `true` si el usuario tiene una rutina personalizada guardada, `false` si usa la default.
  - `saveRoutine(newRutina: RutinaData): Promise<void>`: valida, normaliza y guarda inmediatamente en local; encola pendiente y sube a Supabase.
  - `resetRoutine(): Promise<void>`: vuelve de inmediato a la default en local; encola y ejecuta el borrado en Supabase.
  - `isLoaded: boolean`: disponibilidad de datos.
  - `syncStatus: 'synced' | 'pending' | 'syncing' | 'error'`: estado de la sincronización.
- **Lógica pura y resolución de conflictos:** [`src/utils/routineSync.ts`](src/utils/routineSync.ts) (`getDefaultRoutine`, `parseAndValidateRoutineCache`, `loadRoutineCache`, `saveRoutineCache`, `resolveRoutineConflict`, `getEffectiveRoutine`). Ante un conflicto entre local y remoto sin cambios pendientes, gana la última escritura según `updated_at`. Si los datos remotos o locales están corruptos, se descartan de forma segura y se cae a la rutina por defecto sin romper la app.
- **Re-migración de progreso de bloques:** [`src/hooks/useBlockProgress.ts`](src/hooks/useBlockProgress.ts) ahora incluye un efecto que re-ejecuta `migrateBlockProgress` cuando la rutina cambia (por ejemplo al recibir la rutina remota de Supabase o al editar), asegurando que cualquier clave legacy por índice se migre al nuevo mapa sin perder progreso.
- **Tests:** 18 tests unitarios nuevos en [`src/utils/__tests__/routineSync.test.ts`](src/utils/__tests__/routineSync.test.ts). Total del proyecto: 234 tests pasando; `npm run build` (tsc + vite) pasa sin errores ni warnings.

## Sub-tarea 5: Pantalla "Mi rutina" y editor

- **Status:** `[x] done`
- **Intent:** dar una pantalla de edición completa, separada del uso diario y cómoda en celular.
- **Expected Outcomes:**
  - Botón "Mi rutina" al final de Home. Nueva vista `settings` en `App`, sin tocar el flujo de entrenamiento.
  - Edición con borrador: no se aplica nada hasta "Guardar". Si hay cambios sin guardar, volver o cancelar pide confirmación.
  - Se puede editar `objetivo` y `edad`. El nombre sigue saliendo del login.
  - Se pueden crear, borrar y reordenar días. Se pueden crear, borrar, duplicar y reordenar bloques dentro de un día.
  - Se pueden editar por día el nombre, la ubicación y el calentamiento. Por bloque se edita el tipo, el nombre, los tiempos y las rondas según el tipo, y la lista de ejercicios. Cambiar el tipo de un bloque conserva los ejercicios.
  - Reordenar se hace con botones subir y bajar, que son más fiables en celular que arrastrar. Los botones de borrar piden confirmación.
  - Los errores de validación se muestran en el campo o bloque afectado, y "Guardar" queda bloqueado mientras haya errores.
  - Mismo estilo que el resto de la app (Tailwind, tema oscuro, `max-w-md`).
- **Todo List:**
  1. Agregar `settings` a `ViewMode` en [`src/App.tsx`](src/App.tsx:29) y el botón al final de [`src/views/HomeView.tsx`](src/views/HomeView.tsx). Leer ese archivo antes de implementar.
  2. Crear `src/views/RoutineEditorView.tsx`: estado de borrador, detección de cambios, Guardar y Cancelar.
  3. Crear subcomponentes de edición en `src/components/routine-editor/`: lista de días, editor de día, editor de bloque, editor de ejercicios y campos de tiempo según el tipo.
  4. Usar la validación de la sub-tarea 1 para mostrar errores y bloquear el guardado.
  5. Mostrar un aviso corto si se guardan cambios mientras hay bloques completados hoy. El progreso se conserva por id.
  6. Ocultar el `Header` de sync y navegación solo si hace falta. Mantener el botón de volver consistente con las otras vistas.
- **Relevant Context:** [`src/App.tsx`](src/App.tsx), [`src/views/HomeView.tsx`](src/views/HomeView.tsx), [`src/views/DayDetailView.tsx`](src/views/DayDetailView.tsx) como referencia de estilo, [`src/components/Header.tsx`](src/components/Header.tsx), [`src/components/WeightSheet.tsx`](src/components/WeightSheet.tsx) y [`src/components/VacationSheet.tsx`](src/components/VacationSheet.tsx) como referencia de formularios.

### Notas de implementación (contexto para sub-tareas siguientes)

- **Módulo de lógica pura:** [`src/utils/routineEdit.ts`](src/utils/routineEdit.ts) contiene funciones inmutables y puras para todas las operaciones sobre el borrador (`cloneRutina`, `hasRoutineChanges`, `updateRoutineMeta`, `addDay`, `updateDay`, `removeDay`, `moveDay`, `addBlock`, `updateBlock`, `changeBlockType`, `duplicateBlock`, `removeBlock`, `moveBlock`, `addExercise`, `updateExercise`, `removeExercise`, `moveExercise`, `regenerateTabataStructure`, `renumberEmomExercises`).
- **Comportamiento Tabata / Triserie:** `updateBlock` regenera automáticamente `estructura` en bloques Tabata cuando cambian rondas o tiempos de trabajo/descanso, y elimina el string legacy `descanso_entre_rondas` en Triserie/Density cuando se actualiza `descanso_seg`.
- **Comportamiento EMOM:** `changeBlockType`, `addExercise`, `removeExercise`, `moveExercise` renumeran `minuto` (1..N) automáticamente al agregar/mover/eliminar ejercicios en bloques EMOM y limpian `minuto` al cambiar de EMOM a otros tipos.
- **Subcomponentes creados:** en `src/components/routine-editor/` (`RoutineMetaEditor`, `DayEditor`, `BlockEditor`, `ExerciseEditor`, `RoutineBackupSection`).
- **Hook y navegación en `App.tsx`:** `App.tsx` desestructura `{ rutina, saveRoutine, syncStatus: routineSyncStatus }` de `useRoutine` y pasa el estado y callbacks a `RoutineEditorView` en la vista `settings`. Al entrar se limpian `selectedDayId` y `activeBlock`.
- **Lugar para Sub-tarea 6:** `RoutineBackupSection` (`src/components/routine-editor/RoutineBackupSection.tsx`) ya está ubicado al final de `RoutineEditorView` con los botones de Exportar, Importar y Restaurar como placeholders deshabilitados. Para enganchar la Sub-tarea 6:
  - Reemplazar los botones deshabilitados por los handlers reales.
  - Para cargar un borrador importado: validar con `validateRutina(parsed)` + `normalizeRutina(parsed)` y hacer `setDraft({ ...parsedNormalized, usuario: draft.usuario })`.
  - Para restaurar original: llamar a `getDefaultRoutine(draft.usuario)` de `src/utils/routineSync.ts` y hacer `setDraft(defaultRutina)`.
- **Para Sub-tarea 7 (Pruebas manuales a realizar):**
  - Entrar a "Mi rutina" desde Home.
  - Modificar objetivo/edad, agregar/editar/reordenar/duplicar/borrar bloques y días.
  - Comprobar que cancelar con cambios pide confirmación y descarta sin tocar la rutina activa.
  - Guardar cambios y comprobar actualización en Home y detalle de días.
  - Probar que un bloque completado hoy mantiene su estado completado por su id.
- **Tests y compilación:** 21 tests nuevos en [`src/utils/__tests__/routineEdit.test.ts`](src/utils/__tests__/routineEdit.test.ts). Total: 260 tests pasando (`npm test`), `npm run build` (tsc + vite) pasa sin errores ni warnings.

## Sub-tarea 6: Importar, exportar y restaurar

- **Status:** `[ ] pending`
- **Intent:** poder cargar una rutina completa desde JSON, hacer backup y volver a la rutina original.
- **Expected Outcomes:**
  - **Exportar** descarga un `.json` de la rutina actual y también permite copiarlo.
  - **Importar** acepta un archivo `.json` o texto pegado. Se valida con la misma validación del editor. Si es válido, carga el resultado como borrador, sin guardar. Si no es válido, muestra errores claros y no cambia nada.
  - **Restaurar original** vuelve a la rutina default y pide confirmación.
  - El `usuario` de un JSON importado se ignora: siempre manda el nombre del login.
- **Todo List:**
  1. Agregar a `RoutineEditorView` las acciones Exportar, Importar y Restaurar.
  2. Limitar el tamaño del archivo importado y parsear con `JSON.parse` dentro de `try/catch`. Pasar el resultado por validación y normalización. Mostrar errores genéricos, sin detalles internos.
  3. Mostrar la confirmación antes de reemplazar el borrador con lo importado o con la default.
- **Relevant Context:** el módulo de utilidades de rutina de la sub-tarea 1. La regla de seguridad de validar toda entrada del usuario con allowlists y rechazar lo inválido.

## Sub-tarea 7: Tests y verificación final

- **Status:** `[ ] pending`
- **Intent:** cubrir la lógica nueva y comprobar que nada del uso diario se rompió.
- **Expected Outcomes:**
  - Tests con Vitest para normalización, validación, conversión de claves de progreso, `isDayFinished` con bloques agregados o borrados, y la lógica de pasos de los timers que se pueda aislar.
  - Typecheck, lint, tests y build pasan sin warnings nuevos.
  - Prueba manual de punta a punta: usuario nuevo con rutina default, editar y guardar, ver el cambio en otro dispositivo, completar un bloque, editar la rutina con ese progreso hecho y comprobar que no se pierde, importar un JSON inválido, restaurar original, y probar offline.
- **Todo List:**
  1. Escribir los tests en `src/gamification/__tests__/` o junto a las utilidades nuevas, siguiendo el patrón existente.
  2. Ejecutar los scripts de `package.json` (tests, typecheck, build).
  3. Hacer la prueba manual y anotar lo que falle.
- **Relevant Context:** [`package.json`](package.json), [`src/gamification/__tests__/`](src/gamification/__tests__).

---

## Orden y dependencias

Las sub-tareas 1 a 7 van en ese orden. La 1 no depende de nada. La 2, la 3 y la 4 dependen de la 1. La 5 depende de la 1 y la 4. La 6 depende de la 5. La 7 cierra todo.

## Riesgos a vigilar

- **Timers:** hoy tienen valores fijos y poca cobertura de tests. Hay que verificarlos a mano con la rutina nueva.
- **Progreso de hoy:** la conversión de claves por índice a ids debe correr una sola vez y no perder datos.
- **Migración SQL:** si no se ejecuta, la rutina funciona solo en local y el hook debe tolerarlo sin romper la app.
- **Días borrados:** el historial de actividades conserva su `dayId` aunque el día ya no exista. Las vistas de analytics no deben fallar por eso.
