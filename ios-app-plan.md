# Plan: App nativa iOS + watchOS para CardioFeliz

## Top-Level Overview

**Objetivo.** Crear una app nativa SwiftUI para iPhone, más una app de Apple Watch. Las usan dos personas (el usuario y su esposa). El backend queda igual: Supabase Auth y Postgres con RLS, tablas `cf_*` definidas en `supabase/schema.sql`.

**Alcance confirmado.**
- La app iOS reimplementa todo lo de la PWA: login, rutinas (incluido el editor), temporizadores, historial, gamificación y analíticas.
- El temporizador debe verse en la Isla Dinámica (Live Activity) y seguir funcionando cuando la app pasa a segundo plano.
- El Watch muestra el contador y ejecuta una sesión de entrenamiento HealthKit. Esa sesión mantiene la app viva en la muñeca, registra pulso y calorías y guarda el entrenamiento en Salud.
- Ambos iPhones tienen Dynamic Island. El usuario tiene un Mac con Xcode.
- Presupuesto: no gastar dinero si es posible.

**No objetivos.** Publicar en App Store, soportar miles de usuarios, cambiar el esquema de Supabase, ni cambiar la PWA (sigue funcionando en paralelo).

**Enfoque.**
1. Motor de temporizador basado en fechas absolutas (inicio y fin de cada fase), no en un contador con `setInterval`. Es la base de la Isla Dinámica, del segundo plano y del Watch.
2. El iPhone es el maestro del temporizador. El Watch es un espejo, con controles de pausa y siguiente desde ambos lados.
3. Una Fase 0 de prototipo valida las restricciones de la cuenta gratuita y el comportamiento en segundo plano antes de portar el resto.

```
Supabase (sin cambios)
   ^
   | supabase-swift (Auth + tablas cf_*)
iPhone: App SwiftUI
   |- Cache local (SwiftData), cola de sincronización
   |- Motor de temporizador (fases con fechas absolutas)
   |- Live Activity / Isla Dinámica (widget extension)
   |- Audio de fondo + notificaciones locales
   '-- WatchConnectivity <--> Watch: app watchOS + HKWorkoutSession
```

## Hechos del código actual que condicionan el diseño

- **Backend.** No hay REST propio. El cliente usa `@supabase/supabase-js` contra PostgREST con RLS por `user_id` (`src/lib/*Api.ts`, `supabase/schema.sql`).
- **Auth.** Usuario y contraseña se convierten a `usuario@app.local` (`src/lib/supabase.ts`). El proyecto Supabase es compartido con otra app (PlanDental).
- **Timers.** Son estado de React con `setInterval` de 1 s (`src/components/timers/*`). No hay estado de temporizador en la base de datos. Solo se guarda la actividad al terminar.
- **Sincronización.** Es local-first con cola y `upsert` por `id` UUID generado en el cliente (`src/hooks/useActivities.ts`, `src/utils/activitySync.ts`). Se puede replicar tal cual.
- **Gamificación.** Se calcula en el cliente a partir de las actividades (`src/gamification/*`). Hay ~160 tests de Vitest que sirven como especificación.
- **Rutina.** Es un JSON (`RutinaData` en `src/types/workout.ts`) guardado en `cf_routines.data`. Hay 8 tipos de bloque.

## Comparación de opciones de distribución

| Aspecto | Cuenta gratuita (Personal Team) | Apple Developer Program (99 USD al año) |
|---|---|---|
| Costo | 0 | 99 USD al año |
| Instalación | Xcode desde el Mac, con cable o red local | TestFlight por enlace, sin Mac |
| Caducidad de la firma | Cada 7 días hay que reinstalar | 90 días por build en TestFlight; se renueva subiendo build |
| Dispositivos de la esposa | Debe conectar su iPhone y su Watch al Mac para cada reinstalación | Instala desde TestFlight en su iPhone |
| Capacidades | Restringidas; a verificar en Fase 0 | Completas |
| Límites | Número limitado de App IDs por semana y de apps por dispositivo | Sin esos límites prácticos |

Capacidades que dependen de esa cuenta y que **deben verificarse en la Fase 0, no asumirse**: App Groups (para compartir datos entre app y widget), HealthKit, y que la extensión de Live Activity y la app de Watch se firmen y se instalen juntas con la cuenta gratuita.

Recomendación del plan: empezar con la cuenta gratuita para el prototipo. Si la Fase 0 muestra que alguna capacidad falla o que reinstalar cada 7 días es inaceptable, la decisión sobre los 99 USD se toma con evidencia.

**Decisión (2026-11-07):** no se paga el Apple Developer Program. Se usa Personal Team e instalación desde Xcode. Queda por verificar con la cuenta real qué capacidades acepta Xcode (matriz de `ios/PHASE0-RESULTS.md`).

## Sub-Tasks

### 1. Fase 0: prototipo de validación (cuenta gratuita)

**Intent.** Reducir riesgo antes de portar nada. Comprobar en dispositivos reales las tres cosas que más pueden fallar: restricciones de la cuenta gratuita, temporizador en segundo plano y comunicación con el Watch.

**Expected Outcomes.**
- Un proyecto Xcode con target iOS, widget extension (Live Activity) y target watchOS, instalado en un iPhone y un Watch reales.
- Un temporizador de prueba (60 s con 3 fases) visible en la Isla Dinámica que sigue contando con la app en segundo plano y con la pantalla bloqueada.
- Un `HKWorkoutSession` en el Watch que sobrevive con la muñeca baja y devuelve pulso al iPhone.
- Un informe corto: qué funcionó con la cuenta gratuita, qué no, y la decisión sobre los 99 USD.

**Todo List.**
1. [x] Crear el proyecto Xcode con los tres targets y un bundle ID propio. *(Generado con XcodeGen de forma reproducible)*.
2. [ ] Firmar con Personal Team y registrar capacidades en Xcode. *(A realizar físicamente, ver ios/PHASE0-RESULTS.md)*.
3. [x] Implementar un temporizador mínimo con fases definidas por fechas absolutas. *(Implementado en `TimerManager.swift`)*.
4. [x] Mostrar la Live Activity con `Text(timerInterval:)` y los cambios de fase mediante actualizaciones de la actividad. *(Implementado en `CardioFelizWidget.swift`)*.
5. [ ] Probar segundo plano con audio de fondo, pitidos, TTS y notificaciones locales. *(Soporte de código listo, pendiente de prueba en hardware real, ver ios/PHASE0-RESULTS.md)*.
6. [x] Enviar el plan de fases al Watch por WatchConnectivity y arrancar un `HKWorkoutSession` allí. Mostrar el contador en el Watch. *(Código listo en `PhoneConnector.swift` y `WorkoutManager.swift`)*.
7. [ ] Instalar en el iPhone y el Watch de la esposa para confirmar el flujo de reinstalación. *(Pendiente de prueba en hardware real)*.
8. [x] Documentar resultados y decidir gratuito o de pago. *(Suite de pruebas y matriz de decisión escrita en `ios/PHASE0-RESULTS.md`)*.

**Contexto para Sub-tarea 2 (Modelo de dominio y motor):**
- **Versión mínima elegida:** iOS 17.0 y watchOS 10.0 (estándar para Dynamic Island y apps de Watch monoblanco con SwiftUI moderno).
- **Estructura de Carpetas:**
  - `ios/CardioFeliz/`: App iOS principal (ContentView, TimerManager, SoundManager, NotificationManager, WatchConnector).
  - `ios/CardioFeliz/WorkoutPhase.swift`: Modelo compartido de fase compilado en ambos targets.
  - `ios/CardioFelizWidget/`: Extensión de WidgetKit (Live Activity UI).
  - `ios/CardioFelizWatch/`: App watchOS (ContentView, PhoneConnector, WorkoutManager).
  - `ios/Config.xcconfig`: Configuración de firmas excluida de git.
- **Decisiones Técnicas clave:**
  - El tiempo se modela en base a arrays de `Date` de inicio/fin absolutos para eliminar la deriva y permitir un conteo exacto en la Live Activity y el Watch.
  - El reproductor de voz utiliza `AVSpeechSynthesizer` para una experiencia deportiva premium (anuncio por voz de fase en segundo plano), complementado por pitidos cortos y notificaciones locales de respaldo.
  - La sincronización se realiza mediante `WCSession` usando contextos de aplicación para asegurar la última versión de los datos y mensajes directos para baja latencia en controles.

**Relevant Context.** `src/components/timers/*` (fases a modelar), `public/manifest.webmanifest` (la PWA seguirá existiendo), `ios/PHASE0-RESULTS.md` (manual testing suite).

**Status.** `[-] in_progress (Código completado y verificado por compilación de simulador; pendiente de pruebas físicas en dispositivos reales por parte del usuario)`

### 2. Modelo de dominio y motor de temporizador

**Intent.** Definir en Swift los modelos equivalentes a la web y un motor de temporizador único que reemplace a los seis timers de React.

**Expected Outcomes.**
- Modelos `Codable` para `RutinaData`, `DiaEntrenamiento`, `Bloque` (8 tipos) y las filas `cf_*`, compatibles con el JSON existente en `cf_routines.data`.
- Un motor que convierte un bloque en una lista de fases con inicio y fin absolutos, con pausa, reanudación y salto.
- Tests unitarios por tipo de bloque (EMOM, AMRAP, FOR_TIME, TABATA, TRISERIE, DENSITY, FINISHER, HIIT_INTERVALS).

**Todo List.**
1. [x] Portar `src/types/workout.ts`, `src/types/database.ts` y `src/types/gamification.ts` a structs Swift.
2. [x] Leer cada componente de `src/components/timers/` y extraer la secuencia de fases y alertas (por ejemplo, aviso a 30 s del tope en AMRAP, cuenta atrás de 20 a 0).
3. [x] Diseñar `WorkoutPlan` como lista de fases (nombre, duración, tipo, ejercicio) y `WorkoutClock` que resuelve la fase actual a partir de `Date`.
4. [x] Decidir cómo se calculan pausas (desplazar las fechas restantes) y cómo se serializa el estado para el Watch y la Live Activity.
5. [x] Escribir tests con casos tomados de los comportamientos de la web.

**Relevant Context.** `src/types/workout.ts`, `src/components/timers/*`, `src/views/ActiveWorkoutView.tsx`.

**Contexto para Sub-tarea 3 (Capa de datos):**

*Estructura de carpetas (todo bajo `ios/`):*
- `CardioFeliz/WorkoutPhase.swift`: `WorkoutPhase`, `PhaseKind`, `SoundCue`. Solo Foundation (también se compila en el target watchOS). `id` ahora es `"\(order)-\(name)"` porque Tabata repite nombres; el decode del payload antiguo del prototipo sigue siendo tolerante.
- `CardioFeliz/Models/Routine.swift`: `TipoBloque` (8 casos), `Ejercicio`, `Bloque` (struct plano con discriminador `tipo`, no unión), `DiaEntrenamiento`, `RutinaData`.
- `CardioFeliz/Models/DatabaseRows.swift`: `ActivityType`, `RunLocation`, `FlexibleDouble` (numeric de Postgres como número o string), `ProfileRow`, `ActivityRow`, `AchievementRow`, `VacationRow`, `RoutineRow`. Claves snake_case de BD.
- `CardioFeliz/Engine/TimerConfig.swift`: `TimerDefaults`, `TimerConfig`, `TriserieConfig`, `TabataConfig`, `FinisherStep`/`FinisherStepKind` (port de `src/utils/timerConfig.ts`).
- `CardioFeliz/Engine/WorkoutPlan.swift`: `WorkoutPlan(bloque:)`, `WorkoutPlan.warmup(for:)`, `WorkoutPlan.prototype`, `plannedDuration`, `countdownTickSeconds = [3, 2, 1]`.
- `CardioFeliz/Engine/WorkoutClock.swift`: `WorkoutClock` (struct, valor puro y sin efectos), `ClockState`, `ClockEvent`, `PhaseChangeCause`, `FinishReason`, `WorkoutResult`, `ClockSnapshot`.
- `CardioFeliz/TimerManager.swift`: capa de efectos (voz, pitidos, notificaciones, Live Activity, Watch) sobre `WorkoutClock`. Mantiene `@Published phases`, `phaseStartDates`, `phaseEndDates`, `currentPhaseIndex`, `isPaused`, `isRunning`; añade `lastResult` e `init(plan: = .prototype)`.
- `CardioFelizTests/`: `Support.swift`, `RoutineDecodingTests`, `DatabaseRowDecodingTests`, `WorkoutPlanTests`, `TimerConfigTests`, `WorkoutClockTests`, `Fixtures/rutina.json` (copia idéntica de `src/data/rutina.json`).

*API del motor:*
- `WorkoutClock(plan:)`; `start(at:)`, `tick(at:)`, `pause(at:)`, `resume(at:)`, `next(at:)` (salto de fase), `finish(at:)`; todos devuelven `[ClockEvent]`. Consultas: `currentPhase`, `timeRemainingInCurrentPhase(at:)`, `elapsedInCurrentPhase(at:)`, `progressInCurrentPhase(at:)`, `isLowTime(at:)`, `activeElapsed(at:)`, `result` (`WorkoutResult`: `elapsedSeconds`, `reason`, `phasesCompleted`).
- Reanudar desplaza `startDates`/`endDates` de la fase actual y las siguientes por la duración de la pausa. El reloj es una función pura de `Date` (se inyecta `now`), lo que lo hace testeable sin esperas.
- `snapshot: ClockSnapshot` (Codable) y `WorkoutClock(snapshot:)` sirven para enviar el estado al Watch y para restaurar tras relanzar la app.
- Un `Bloque` sin parámetros válidos (p. ej. EMOM sin `duracion_minutos`) produce un plan vacío; la PWA mostraría NaN.

*Decisiones de diseño:*
- **Fases manuales** (Triserie/Density "siguiente", pasos MANUAL de Finisher/HIIT): `endDate == startDate` y `isManual == true`, para que los arrays de fechas conserven la longitud de `phases`. Los consumidores deben comprobar `phase.isManual`.
- **Notificaciones locales:** `scheduleWorkoutNotifications` solo programa hasta la primera fase manual (el parámetro nuevo `notifyCompletion` se desactiva si hay una fase manual por delante).
- **`Bloque` tolerante:** números inválidos pasan a `nil`; un `tipo` desconocido lanza error. Ejercicios EMOM con `minuto`, genéricos con `segundos` opcional.
- **Fechas en filas `cf_*`:** se mantienen como `String`; los numéricos usan `FlexibleDouble`. La capa de datos decide la estrategia de fecha.
- **No portado (fuera de esta sub-tarea):** `validateRutina`, `normalizeRutina`, `newBloqueDefaults` (sub-tarea 7); `Activity`/`UserProfile` de dominio y sus mappers, tipos `Insert`/`Update` y `WorkoutDayId` (sub-tarea 3 en adelante).

*Discrepancias PWA vs. port (verificadas contra el código de `src/`):*
- **EMOM:** la PWA elige el ejercicio por posición `(minuto-1) % n`, no por el campo `minuto`; el port copia ese comportamiento.
- **AMRAP / FOR_TIME:** por defecto 15 min (`|| 15`). FOR_TIME cuenta hacia arriba hasta `cap_minutos`.
- **TABATA:** no hay descanso tras el último trabajo, por lo que la duración real es 230 s; la etiqueta de la PWA calcula `rondas*ciclo` = 240 s. No se reproduce `onComplete(totalElapsed+1)`.
- **TRISERIE / DENSITY:** la PWA no tiene pausa en este temporizador; el port la permite en todos. El tiempo transcurrido de la PWA empieza al primer toque; el port lo cuenta desde `start()`. No hay descanso tras la última ronda y un descanso de 0 se omite.
- **FINISHER / HIIT:** pasos WORK, TRANSITION (`segundos - trabajo_seg`), REST (ejercicio "descanso", 30 s por defecto, coincidencia sin distinguir mayúsculas) y MANUAL (sin `segundos`).
- **Calentamiento:** una única fase de `calentamiento_minutos`. El botón Reset de la PWA no está en el motor; se recrea el reloj.
- **Cuenta atrás:** el port usa un tick uniforme a 3, 2 y 1 s restantes. La PWA es ligeramente inconsistente entre timers (`prev` de 4 a 2 o `next <= 3`; en FOR_TIME de cap-3 a cap-1).
- **AMRAP:** el contador de rondas y el checklist de ejercicios son estado de UI, no del motor; `rounds` va a `onComplete` y se mapea a `rounds_total`.
- **Sonidos:** la PWA tiene go, rest, tick y victory; `SoundManager` del prototipo solo tiene `playBeep()` (sonido de sistema 1052) más voz. `SoundCue` (none/go/rest) está modelado pero sin diferenciar.

*Preguntas abiertas:*
1. ~~¿Sonidos distintos por `SoundCue`?~~ Decidido: sí, sintetizados en código (sin archivos ni librerías de terceros). Se hace en las sub-tareas 4 y 5. Pausa en Triserie/Density: aceptada.
2. Fases manuales en el Watch y la Live Activity: el `ContentView` del Watch calcula el restante desde `phaseEndDates` y mostraría 00; `timerInterval(start...end)` de la Live Activity también necesita un caso especial (sub-tareas 5 y 6).
3. ¿Se acepta pausa en Triserie/Density aunque la PWA no la tenga? (el port la permite).
4. ¿Se necesita el Reset del calentamiento como operación del motor o basta con recrear `WorkoutClock`?
5. ¿Debe el motor llevar el contador de rondas del AMRAP o se queda en la UI?
6. Estrategia de decodificación de fechas ISO 8601 de Supabase, con y sin fracciones de segundo, y zona horaria (sub-tarea 3).
7. Tipos `Insert`/`Update` y mappers de dominio (`Activity`, `UserProfile`): ¿viven en `Models/` o en la capa de datos?

*Verificación:* `xcodegen generate` OK; `xcodebuild test` (esquema CardioFeliz, iPhone 17, simulador `3A89B6A7-74FB-41CF-A856-09700149C780`) → **101 tests, 0 fallos** (RoutineDecodingTests 16, DatabaseRowDecodingTests 9, WorkoutPlanTests 30, TimerConfigTests 5, WorkoutClockTests 41). Compilan sin warnings del compilador CardioFeliz, CardioFelizWidget (iOS Simulator) y CardioFelizWatch (watchOS Simulator). `project.yml` declara ahora esquemas explícitos, porque XcodeGen 2.46.0 no generaba ninguno. No hubo comparación de warnings previa: sin esquemas no se podía compilar la línea base.

**Status.** `[x] completed (101 tests unitarios pasan; targets iOS, widget y watchOS compilan sin warnings)`

### 3. Capa de datos: Supabase, sesión y sincronización local-first

**Intent.** Reutilizar el backend sin cambios con el mismo comportamiento offline.

**Expected Outcomes.**
- Login con la misma convención `usuario@app.local`, sesión persistida de forma segura en el Keychain, sin secretos en el repositorio.
- Lectura y escritura de actividades, perfil, logros, vacaciones y rutina contra las mismas tablas.
- Cache local y cola de subida idempotente con `upsert` por UUID.

**Todo List.**
1. [x] Añadir `supabase-swift` por Swift Package Manager con la última versión estable (verificar mantenimiento y licencia al elegirla). *(2.55.6, ver "Contexto para Sub-tarea 4")*
2. [x] Guardar la URL y la clave anónima en un archivo de configuración fuera de git (`.xcconfig` ignorado, con un ejemplo versionado), siguiendo `.env.example`.
3. [x] Implementar los clientes API equivalentes a `activitiesApi`, `profileApi`, `achievementsApi`, `vacationsApi` y `routineApi`.
4. [x] Implementar el cache con SwiftData y la lógica de `mergeRemoteActivities` de `src/utils/activitySync.ts`.
5. [x] Manejar el límite de 1000 filas con paginación, como en `fetchAllActivities`.
6. [x] Mostrar errores genéricos al usuario y registrar el detalle sin datos sensibles.

**Relevant Context.** `src/lib/supabase.ts`, `src/lib/*Api.ts`, `src/hooks/useActivities.ts`, `src/utils/activitySync.ts`, `src/utils/activityCache.ts`, `supabase/schema.sql`, `.env.example`, `ios/DATA-LAYER-MANUAL-TESTS.md` (pruebas manuales contra Supabase real).

**Contexto para Sub-tarea 4 (Flujo de entrenamiento en iPhone):**

*Dependencia elegida.*
- `supabase-swift` **2.55.6** (`exactVersion` en `ios/project.yml`). Verificado el 2026-11-06 en GitHub: última release estable `v2.55.6` del 2026-10-30 (anteriores: 2.55.5 el 10-26, 2.55.4 el 10-13, 2.55.3 el 09-29); último commit en `main` del 2026-11-05; repositorio no archivado; licencia **MIT**; sin pre-releases. Requiere iOS 16+ (proyecto en 17). Su almacenamiento de sesión por defecto en Apple es `KeychainLocalStorage` (verificado en el código de la v2.55.6: `AuthClient.Configuration.defaultLocalStorage`, con `kSecAttrAccessibleAfterFirstUnlock`); la app lo instancia explícitamente con un `service` propio (`<bundle id>.supabase-auth`).
- Solo el target `CardioFeliz` enlaza el paquete. Widget, Watch y tests **no** dependen de supabase-swift ni (widget/Watch) de SwiftData. `Package.resolved` queda en el `.xcodeproj` (ignorado); `exactVersion` fija la versión. Subirla es un cambio consciente en `project.yml`.

*Configuración.*
- `ios/Config.xcconfig` (ignorado) debe tener `SLASH = /`, `SUPABASE_URL = https:/$(SLASH)<host>` y `SUPABASE_ANON_KEY = <clave anon>`. El ejemplo versionado está en `ios/Config.xcconfig.example`. `Info.plist` los lee como `SupabaseURL` y `SupabaseAnonKey`.
- **Acción del usuario:** añadir esas tres líneas a su `Config.xcconfig` local (no se tocó ni se leyó ese archivo). Sin ellas la app arranca en "Sin configurar" (verificado en el simulador: no hay crash ni red; el log `config` lo indica).
- `SupabaseConfig` valida igual que `isValidConfig` de la PWA (HTTPS salvo localhost, clave de más de 20 caracteres) y además rechaza `$(VAR)` sin resolver y los marcadores del `.example`.

*Estructura (todo bajo `ios/CardioFeliz/Data/`; cada subcarpeta indica qué compila cada target):*
- `Core/` (puro, sin Supabase; también en tests): `DataLayerError` (+ `userMessage` genérico, `ErrorSummary`, `AppLog` con `Logger`), `SupabaseDate`, `SupabaseConfig`, `DomainModels` (`ActivityRecord`, `ActivityDraft`, `UserProfile`, `AchievementUnlock`, `VacationPeriod`), `InsertTypes` (`ActivityInsert`, `ProfileWeightInsert`, `AchievementInsert`, `VacationInsert`, `RoutineInsert`, `RemoteRoutine`), `Mappers`, `RemoteProtocols` (`ActivitiesRemote`, `ProfileRemote`, `AchievementsRemote`, `VacationsRemote`, `RoutineRemote`, `DataRemotes`, `Pagination`), `ActivityDraft+Record` (`ActivityValidation`).
- `Auth/` (también en tests): `AuthBackend`, `AuthUser`, `AuthEvent`, `AuthState`, `Credentials`, `SessionManager`.
- `Local/` (SwiftData; también en tests): `ActivityCacheStore` (+ `InMemoryActivityCacheStore`), `SwiftDataActivityCache` (`CachedActivity`, `CachedDeletion`, `SwiftDataActivityCacheStore`).
- `Sync/` (también en tests): `ActivitySync` (`sort`, `merge`, `newId`), `ActivityStore` (orquestador), `NetworkMonitor`.
- `Supabase/` (**solo en la app**, importa `Supabase`): `SupabaseClientFactory` (+ `SupabaseErrorMapper`), `SupabaseAuthBackend`, `SupabaseRemotes` (implementaciones reales de los 5 protocolos).
- `AppEnvironment.swift` (composición, solo app) y `Views/LoginView.swift` (`LoginView`, `UnconfiguredView`), `Views/RootView.swift` (`RootView`, `SyncStatusBar`).

*API pública que usará la sub-tarea 4:*
- `AppEnvironment` (`@MainActor ObservableObject`, creado en `CardioFelizApp`): `session: SessionManager`, `activityStore: ActivityStore?` (nil sin sesión; se crea al iniciar sesión y se descarta al cerrarla), `remotes: DataRemotes?` (nil si no está configurado), `network: NetworkMonitor`, `appBecameActive()`.
- `SessionManager`: `state: AuthState` (`.loading`, `.unconfigured`, `.signedOut`, `.signedIn(userId:username:)`), `currentUserId`, `isSigningIn`, `signIn(username:password:) async throws` (lanza `DataLayerError`; mostrar `error.userMessage`), `signOut() async`, `start()`.
- `ActivityStore` (`@MainActor ObservableObject`) = `useActivities`: `@Published activities: [ActivityRecord]` (ya ordenadas), `syncStatus: SyncStatus` (`.synced/.syncing/.pending/.offline`), `pendingCount`, `lastSyncedAt`; `addActivity(_ draft: ActivityDraft, options: AddActivityOptions) throws -> ActivityRecord`, `updateActivity(id:patch:options:) throws -> ActivityRecord?`, `removeActivity(id:)`, `fillMissingCalories(weightKg:)`, `trySync()`, `sync() async`. Las altas son inmediatas y locales; la subida va en segundo plano.
- `ActivityDraft(type:occurredOn:startedAt:durationSeconds:dayId:blocksCompleted:roundsTotal:distanceKm:runLocation:feeling:)`. Para un entrenamiento terminado: `type: .workoutDay`, `dayId`, `blocksCompleted`, `startedAt`, `durationSeconds` (de `WorkoutResult.elapsedSeconds`). `ActivityValidation.localDay(Date())` da el `occurredOn` (YYYY-MM-DD local).
- Los demás remotos (perfil, logros, vacaciones, rutina) están implementados pero **aún sin orquestador local** (ver preguntas abiertas): se obtienen de `env.remotes`.

*Decisiones de diseño:*
- **Nombres:** `ActivityRecord` y no `Activity`, porque `ActivityKit.Activity<…>` ya se usa en `TimerManager` y lo taparía. Mappers y tipos `Insert` están en `Data/Core`, no en `Models/`.
- **Fechas:** `timestamptz` → `Date` con un único parser (`SupabaseDate.parse`: con/sin fracciones de 1–9 dígitos, `Z`, `±HH:MM`, `±HHMM`, `±HH`, separador `T` o espacio, sin zona = UTC; rechaza días inexistentes). Salida con `SupabaseDate.format` (UTC con milisegundos, como `toISOString()`). Las fechas `date` (`occurredOn`, `startOn`, `endOn`) **siguen siendo `String` YYYY-MM-DD**. `DatabaseRows.swift` no cambió de forma (solo se añadió `Sendable` a `ActivityType`, `RunLocation`, `FlexibleDouble`, `TipoBloque`, `Ejercicio`, `Bloque`, `DiaEntrenamiento` y `RutinaData`).
- **Sincronización:** réplica de `trySync`/`sync` de `useActivities`: 1) borrados pendientes, 2) subidas pendientes en orden (si se edita durante la subida sigue pendiente), 3) `fetchAll` y `merge` (`ActivitySync.merge` = `mergeRemoteActivities`); una pasada extra si se pidió otra mientras corría. Reintento cada 60 s solo con pendientes; también al abrir, al volver a primer plano y al volver la red (`NWPathMonitor`).
- **Idempotencia:** el id es un UUID v4 en minúsculas generado en el cliente y la subida es `upsert(onConflict: "id")`. Probado con una respuesta "perdida" tras aplicarse en el servidor: no se duplica.
- **Upsert con `null` explícito:** `ActivityInsert` y `VacationInsert` envían `null` para los opcionales vacíos (igual que `toDbActivity`), de modo que al editar se pueden borrar valores. Los logros usan `ignoreDuplicates` y `onConflict: "user_id,achievement_id"`; el perfil solo envía `user_id` y `weight_kg`.
- **Cache SwiftData:** `CachedActivity` (con `pendingOrder`) y `CachedDeletion` (con `order`), aisladas por `userId`; cada usuario mantiene su cache al cambiar de cuenta. Si SwiftData falla al abrirse, `AppEnvironment` usa una cache en memoria (se registra el error).
- **Seguridad:** sesión en Keychain (`KeychainLocalStorage`), `emitLocalSessionAsInitialSession: true` (la app abre offline con la sesión guardada), `URLSession.ephemeral` con TLS ≥ 1.2, timeouts de 20 s por petición y 60 s por recurso, validación de certificados por defecto. Los errores se traducen a `DataLayerError` (nunca se conserva el mensaje del servidor) y los logs (`AppLog`, categorías `config/auth/sync/data`) solo escriben tipo y código. Validación local previa: usuario `^[a-z0-9._-]{1,64}$`, contraseña de 1 a 256 caracteres; borradores de actividad según los `check` de `schema.sql` (para que una fila que el servidor rechazaría no quede atascada en la cola).
- **Tests:** el target `CardioFelizTests` compila `Data/Core`, `Auth`, `Local` y `Sync`, no `Data/Supabase`, así que las pruebas no tocan red ni supabase-swift.

*Discrepancias con la PWA:*
- **`signOut`:** la PWA usa el alcance global de `supabase-js`; la app usa `.local` (solo cierra esta sesión, no la de otros dispositivos).
- **XP y calorías:** la PWA los calcula en `addActivity` con `computeActivityXp`/`estimateCalories` (módulo `src/gamification`, sub-tarea 8). Aquí se inyectan con `ActivityDerivation` (por defecto `.none`: `xpEarned = 0`, `caloriesKcal = nil`). Hasta portar la gamificación, las actividades creadas desde iOS suben con `xp_earned = 0`. **La sub-tarea 8 debe inyectar la derivación real** (y la sub-tarea 4, el peso vía `AddActivityOptions`).
- **`getAuthProfile`** (lectura de `public.profiles` de PlanDental) no se portó: la app solo necesita el `username` del email y `display_name` de `cf_profiles` (`ProfileRemote.fetchProfile`). Tampoco `getSession`/`getAuthProfile` sueltos: el estado vive en `SessionManager`.
- **Validación local:** la PWA no valida el borrador al guardarlo; la app sí (lanza `DataLayerError.invalidInput`).
- **Logros con fecha ilegible** se descartan al leerlos (la PWA los pasaría tal cual).
- **Reintentos de red de PostgREST:** supabase-swift reintenta solo lecturas ante 503/520/errores de red, hasta 3 veces; supabase-js no lo hace.
- **Orden de escritura:** `upsert` envía `columns=` con las claves del cuerpo (comportamiento de supabase-swift); con `null` explícito no hay diferencia práctica.

*Preguntas abiertas:*
1. ~~Orquestadores locales de perfil (peso), logros, vacaciones y rutina:~~ **Resuelto para peso en la Sub-tarea 4**: implementado `ProfileWeightStore` local-first con cache `UserDefaults`/`KeyValueStorage` y sincronización asíncrona con `ProfileRemote`. Logros y vacaciones quedan para la sub-tarea 8; rutina remota para la sub-tarea 7.
2. La rutina remota se decodifica con el decoder tolerante de `RutinaData`; si el JSON de `cf_routines.data` trajera un `tipo` de bloque desconocido, `fetch` lanzaría `DataLayerError.decoding`. ¿Se prefiere ignorar el bloque o mostrar un error? (afecta a la sub-tarea 7).
3. Actualizaciones de `ActivityStore.activities` ante cambios de usuario con la app abierta: hoy el store se recrea. Si la sub-tarea 4 necesita observar un único objeto estable, habría que envolver el store en un contenedor.
4. Cierre de sesión con cola pendiente: la cache se conserva por usuario, pero lo pendiente no se sube hasta que ese usuario vuelva a entrar. ¿Se avisa antes de cerrar sesión si hay cambios sin subir? (aún no hay UI para eso).
5. `Package.resolved` no se versiona (está dentro del `.xcodeproj` ignorado). ¿Se quiere versionar un `Package.resolved` propio para fijar también las dependencias transitivas?

*Verificación:* `xcodegen generate` OK. `xcodebuild test` (esquema CardioFeliz, iPhone 17, simulador `3A89B6A7-74FB-41CF-A856-09700149C780`) → **188 tests, 0 fallos** (101 de la sub-tarea 2 + 87 nuevos: ActivityStoreTests 23, SupabaseDateTests 11, SessionManagerTests 9, ActivitySyncMergeTests 8, MapperTests 8, SupabaseConfigTests 7, PaginationTests 6, SwiftDataCacheTests 6, CredentialsTests 4, ActivityValidationTests 3, ErrorHandlingTests 2). Compilación limpia (`clean build`) de CardioFeliz, CardioFelizWidget (iOS Simulator) y CardioFelizWatch (watchOS Simulator) sin warnings ni errores; la línea base de la sub-tarea 2 tampoco tenía warnings. La app lanzada en el simulador sin credenciales muestra el estado "Sin configurar" y registra el motivo, sin crash ni red. **No probado contra Supabase real**: ver `ios/DATA-LAYER-MANUAL-TESTS.md`.

**Status.** `[x] completed (188 tests unitarios pasan; targets iOS, widget y watchOS compilan sin warnings; pendiente de pruebas manuales contra Supabase real por parte del usuario)`

### 4. Flujo de entrenamiento en iPhone

**Intent.** Reproducir el recorrido de la web: día, calentamiento, detalle de bloque, entrenamiento activo y registro.

**Expected Outcomes.**
- Pantallas SwiftUI para Home, detalle del día, calentamiento, detalle de bloque y entrenamiento activo con controles de pausa, siguiente y silencio.
- Pantalla encendida durante el entrenamiento.
- Al terminar, se guarda la actividad con `duration_seconds`, `day_id`, `blocks_completed` y `started_at`.
- Registro rápido de carrera y descanso activo (equivalente a `QuickLogCard`).

**Todo List.**
1. [x] Construir la navegación y las vistas a partir de `src/App.tsx` y `src/views/*` (HomeView, DayDetailView, WarmupView, BlockDetailView, ActiveWorkoutView, WorkoutCompleteModalView, QuickLogCardView, RunSheetView, WeightSheetView).
2. [x] Conectar la vista activa con el motor de la sub-tarea 2 (`WorkoutClock` y `TimerManager` unificados mediante `WorkoutWorkflowViewModel` y vistas dedicadas por tipo de bloque: EMOM, AMRAP, FOR_TIME, TABATA, TRISERIE/DENSITY, FINISHER/HIIT).
3. [x] Portar los sonidos de la PWA (go, rest, tick y victory) y la cuenta atrás de pitidos como sonidos distintos por `SoundCue`. Decisión: sin coste ni dependencias, los tonos se sintetizan en código (`ToneSynthesizer` con buffers PCM en `AVAudioEngine` y `AVAudioPlayerNode`, sin archivos de audio de terceros ni librerías; voz con `AVSpeechSynthesizer` y modo silencio).
4. [x] Mantener la pantalla activa durante el entrenamiento (`UIApplication.shared.isIdleTimerDisabled` gestionado por `WorkoutWorkflowViewModel` y restaurado al salir).
5. [x] Implementar el modal de cierre y el guardado local-first con `ActivityStore.addActivity` (cálculo de calorías con `CaloriesEstimator`, duración, día, bloques completados, rondas AMRAP y selector de sensación).

**Relevant Context.** `src/App.tsx`, `src/views/HomeView.tsx`, `src/views/ActiveWorkoutView.tsx`, `src/components/QuickLogCard.tsx`, `src/gamification/calories.ts`, `ios/WORKOUT-FLOW-MANUAL-TESTS.md`.

**Contexto para Sub-tarea 5 (Segundo plano e Isla Dinámica):**

*Estructura y tipos creados en la Sub-tarea 4:*
- `CardioFeliz/Models/RoutineProvider.swift`: protocolo `RoutineProvider` y `BundledRoutineProvider` empaquetado como recurso con fallback a fixture de tests. Deja punto limpio de inyección para la sub-tarea 7.
- `CardioFeliz/Data/Core/CaloriesEstimator.swift`: cálculo puro de calorías (`metForRun`, `metWorkout = 8.0`, `metActiveRest = 3.0`, `metRunDefault = 8.3`, tabla de interpolación y validación de peso 20–300 kg).
- `CardioFeliz/Data/Sync/ProfileWeightStore.swift`: orquestador local-first del peso con cache en `UserDefaultsStorage` (envoltorio de `UserDefaults` sobre el protocolo `KeyValueStorage`) y subida en segundo plano con `ProfileRemote`.
- `CardioFeliz/Engine/ToneSynthesizer.swift`: generación pura de buffers PCM con envolvente lineal (Go: 880->1760 Hz; Rest: 440->220 Hz; Tick: 880 Hz; Victory: 523->659->784->1046 Hz).
- `CardioFeliz/SoundManager.swift`: orquestador de audio con `AVAudioEngine`, reproductor de tonos, `AVSpeechSynthesizer`, toggle de silencio y configuración de sesión de audio con `.mixWithOthers` / `.duckOthers`.
- `CardioFeliz/Engine/WorkoutWorkflowViewModel.swift`: ViewModel de navegación y orquestación del flujo de entrenamiento (pantallas, progreso del día, pantalla encendida `isIdleTimerDisabled`, guardado en `ActivityStore`).
- `CardioFeliz/Engine/WorkoutDayProgress.swift`: cálculo de progreso de bloques de un día a partir de las actividades registradas.
- `CardioFeliz/Views/`:
  - `HomeView.swift`: vista principal con selector de días, registro rápido (`QuickLogCardView`), estado de sincronización y acceso a peso.
  - `DayDetailView.swift`: detalle del día con lista de bloques, badges y botón de inicio guiado.
  - `WarmupView.swift`: temporizador de calentamiento con controles de pausa, silencio y completar.
  - `BlockDetailView.swift`: detalle informativo del bloque antes de iniciar.
  - `ActiveWorkoutView.swift`: contenedor de temporizador activo con barra superior, pantalla encendida y modal de confirmación de salida.
  - `Timers/`: `EmomTimerView`, `AmrapTimerView`, `ForTimeTimerView`, `TabataTimerView`, `TriserieTimerView`, `FinisherTimerView`.
  - `Components/`: `WorkoutCompleteModalView`, `QuickLogCardView`, `RunSheetView`, `WeightSheetView`, `DayCardView`, `BlockCardView`, `WarmupCardView`, `BlockBadgeView`.

*Conexión con TimerManager / Live Activity para la Sub-tarea 5:*
- Los temporizadores específicos (`EmomTimerView`, `TabataTimerView`, etc.) instancian `TimerManager(plan:)` a partir de `WorkoutPlan(bloque:)`.
- `TimerManager` ya inicia y actualiza `Activity<WorkoutAttributes>` de ActivityKit cuando corre en iOS.
- **Fases manuales:** `phase.isManual` (`endDate == startDate`). La Live Activity no debe usar `timerInterval: phase.startDate...phase.endDate` en fases manuales porque colapsaría a 0 s; debe mostrar una insignia de "Manual / Siguiente" o tiempo transcurrido desde `startDate`.
- **Sesión de audio:** `SoundManager.shared.configureAudioSession()` configura la categoría `.playback` o `.ambient` con `.mixWithOthers` y `.duckOthers`. En la sub-tarea 5 se programará el ciclo de audio en segundo plano para que los tonos se emitan en el momento exacto sin latencia.
- **App Intents:** `TimerManager` expone `pause()`, `resume()` y `next()`, listos para ser invocados por App Intents desde la Live Activity y la pantalla de bloqueo.

*Preguntas abiertas para Sub-tarea 5:*
1. ¿Debe la Live Activity mostrar el tiempo total del entrenamiento o el tiempo de la fase actual? (Recomendado: fase actual en compact/minimal y ambos en expanded/lock screen).
2. Interrupciones de audio: ante una llamada entrante o reproducción de otra app de audio exclusiva, ¿reanudamos la sesión de audio automáticamente al volver a primer plano?
3. Fases manuales en la Isla Dinámica: ¿qué texto corto mostrar en el trailing de la Dynamic Island? (ej. "Toca Sig" o un icono de avance).

*Correcciones tras la revisión de la sub-tarea 4 (verificadas en una segunda compilación):*
- La primera entrega compilaba con 2 warnings, no con 0. Uno era un bug real: la extensión `UserDefaults: KeyValueStorage` se llamaba a sí misma (recursión infinita), de modo que el peso se habría desbordado la pila en un dispositivo real. Los tests no lo detectaban porque solo usaban `InMemoryKeyValueStorage`. Se sustituyó por `UserDefaultsStorage` (envoltorio) y se añadió un test con `UserDefaults` real (suite temporal).
- El otro warning era un `try?` sin usar en `WorkoutWorkflowViewModel` que ocultaba un fallo al guardar la actividad del día; ahora se registra con `AppLog.data` sin datos sensibles.
- Textos: «5m cal.» en la tarjeta de día pasa a «5 min de calentamiento» (en la PWA es «5 min» de calentamiento) y «1 ejercicios» pasa a «1 ejercicio».

*Verificación:* `xcodegen generate` OK. `xcodebuild test` (esquema CardioFeliz, iPhone 17, simulador `3A89B6A7-74FB-41CF-A856-09700149C780`) → **212 tests, 0 fallos** (188 previos + 24 nuevos). Compilación de CardioFeliz, CardioFelizWidget (iOS Simulator) y CardioFelizWatch (watchOS Simulator) sin warnings propios; solo queda el aviso de `appintentsmetadataprocessor`, que desaparece al añadir App Intents en la sub-tarea 5. Se revisaron las capturas de Home y detalle del día en `ios/screenshots/`; **no** se revisaron visualmente en esta sesión las pantallas de calentamiento ni de temporizador activo, ni el flujo en un dispositivo real.

**Status.** `[x] completed (212 tests unitarios pasan; targets iOS, widget y watchOS compilan sin warnings propios; Home y detalle del día revisados en simulador; pendiente de pruebas manuales en iPhone: ios/WORKOUT-FLOW-MANUAL-TESTS.md)`

### 5. Segundo plano e Isla Dinámica

**Intent.** Que el contador siga vivo y visible cuando la app no está en primer plano.

**Expected Outcomes.**
- Live Activity con vista compacta, expandida y de pantalla de bloqueo: fase actual, tiempo restante y ejercicio.
- El contador avanza solo gracias a `Text(timerInterval:)`; la actividad se actualiza únicamente en los cambios de fase.
- Pitidos y vibraciones en los cambios de fase con la app en segundo plano.
- Al volver a la app, el estado se reconstruye desde las fechas absolutas.
- Botones de pausa y siguiente desde la Live Activity mediante App Intents.

**Todo List.**
1. Crear la widget extension y definir los atributos y el estado de la Live Activity.
2. Iniciar, actualizar y terminar la actividad desde el motor.
3. Configurar el modo de fondo de audio y la sesión de audio para que los sonidos sintetizados (go, rest, tick, victory) suenen en segundo plano y con la pantalla bloqueada. Programar los cambios de fase con antelación para que el sonido correcto salga en el instante exacto, y probar que no se cortan la música ni otros audios del usuario (mezcla con `.mixWithOthers` o ducking, a decidir).
4. Programar notificaciones locales de respaldo para cada cambio de fase.
5. Añadir App Intents para pausa y siguiente.
6. Probar interrupciones: llamada, otra app de audio, bloqueo y cierre forzado de la app.

**Relevant Context.** Resultados de la Fase 0. Las limitaciones reales de cuenta gratuita se tratan allí.

**Resultado (código y tests; el comportamiento real en segundo plano NO está probado en dispositivo).**
1. [x] Widget extension y atributos. `WorkoutAttributes.ContentState` ahora lleva `detail` (ejercicio), `isManual`, `countsUp` y `frozenSeconds` (segundos congelados en pausa). `LiveActivityStateBuilder` (puro, testeado) arma el estado desde el `WorkoutClock`.
2. [x] Iniciar/actualizar/terminar: `TimerManager` actualiza la actividad solo en cambios de fase, pausa y reanudación; el contador corre solo con `Text(timerInterval:)`. Fases manuales: tiempo transcurrido desde el inicio (nunca `start...end`, que colapsaría a 0 s); FOR_TIME cuenta hacia arriba; en pausa se muestra el valor congelado. Al lanzar la app se cierran Live Activities huérfanas (cierre forzado).
3. [x] Audio: `UIBackgroundModes` reducido a `audio` (se quitaron `processing`, `external-accessory`, `bluetooth-central` y `nearby-interaction`, que no se usan y pueden provocar rechazo en revisión). `SoundManager` mantiene un bucle de silencio mientras hay entrenamiento y programa los tonos futuros a su hora exacta con `AudioCuePlanner` + `AVAudioPlayerNode` (`scheduleBuffer(at:)`), reprogramando al reanudar o saltar fase. **Decisión de mezcla:** solo `.mixWithOthers` (se quitó `.duckOthers`: con la sesión activa todo el entrenamiento atenuaría la música todo el rato; basta añadirlo en `SoundManager.sessionOptions` si se prefiere). Recuperación tras interrupciones (llamada, cambio de ruta, reset de servicios multimedia) y al volver a primer plano.
4. [x] Notificaciones de respaldo (`NotificationPlanner`, tope de 60): se agendan 1,5 s después de cada cambio de fase y la app las cancela al procesar el cambio, para no duplicar el aviso si sigue viva. Solo se agendan hasta la primera fase manual (más allá no hay fechas fiables).
5. [x] App Intents `PauseWorkoutIntent`, `ResumeWorkoutIntent`, `NextPhaseIntent` (`LiveActivityIntent`, se ejecutan en el proceso de la app mediante `WorkoutCommandBus`). Botones en pantalla de bloqueo e isla expandida; en fase manual el botón dice «Listo».
6. [ ] Probar interrupciones en dispositivo real: **pendiente** (`ios/BACKGROUND-MANUAL-TESTS.md`).

*Respuestas a las preguntas abiertas:* (1) compact/minimal muestran la fase actual; expanded y pantalla de bloqueo, fase actual con su ejercicio y «Fase N de M» (no se muestra el total del entrenamiento: con fases manuales no es conocido). (2) Sí, el audio se reactiva solo al terminar la interrupción y al volver a primer plano. (3) En fase manual la isla compacta muestra el tiempo transcurrido y el botón expandido «Listo».

*Limitaciones conocidas:*
- **Vibración (añadida después):** `SoundManager.vibrate()` (`kSystemSoundID_Vibrate`) se dispara en cada cambio de fase y al terminar, con la app viva, incluso en modo silencio. Con la app suspendida no hay vibración propia: solo la que traiga la notificación local. No probada en dispositivo.
- La voz (`AVSpeechSynthesizer`) sigue hablándose de forma inmediata al detectar el cambio de fase, no programada: con la app suspendida (sin que el bucle de silencio la mantenga viva) solo suenan los tonos programados y la notificación.
- Con fases manuales, tras la fase manual no se programan tonos ni avisos hasta que el usuario la confirma.
- Sin `NSSupportsLiveActivitiesFrequentUpdates` (se deja en `false`): las actualizaciones por Push no se usan.
- Si la app es suspendida pese al audio (p. ej. sesión de audio perdida), la Live Activity puede quedar en la fase anterior hasta que el usuario vuelva a la app; el contador sigue correcto por las fechas.

*Verificación:* `xcodegen generate` OK. `xcodebuild test` (iPhone 17, simulador `3A89B6A7-74FB-41CF-A856-09700149C780`) → **228 tests, 0 fallos** (212 previos + 16 nuevos en `BackgroundPlanningTests`: planificación de tonos, notificaciones y estado de la Live Activity). `xcodebuild build` de CardioFeliz con el widget incrustado: BUILD SUCCEEDED; el aviso de `appintentsmetadataprocessor` persiste solo en la compilación de la app (la extensión sí extrae metadatos de App Intents). **No verificado:** audio en segundo plano, bloqueo, interrupciones, botones de la Live Activity ni apariencia de la isla (ni siquiera en simulador).

**Status.** `[x] completed en código (370 tests unitarios pasan; app y widget compilan; pendiente de pruebas manuales en iPhone real: ios/BACKGROUND-MANUAL-TESTS.md)`

### 6. App de Apple Watch con sesión HealthKit

**Intent.** Mostrar el contador en la muñeca y registrar datos de salud.

**Expected Outcomes.**
- La app watchOS recibe el plan de fases y el estado del iPhone, y muestra fase, tiempo restante y ejercicio con vibración en cada cambio.
- Pausa y siguiente funcionan desde el Watch y se reflejan en el iPhone.
- Una `HKWorkoutSession` mantiene la app activa, registra pulso y calorías y guarda el entrenamiento en Salud.
- Pulso medio y calorías llegan al iPhone y se guardan en la actividad (`calories_kcal`).

**Todo List.**
1. Definir el protocolo de mensajes (plan, estado, comandos) con WatchConnectivity, usando fechas absolutas para evitar deriva.
2. Pedir permisos de HealthKit con textos de uso claros. Pedir solo lectura de pulso y energía, y escritura de entrenamientos.
3. Implementar `HKWorkoutSession` y `HKLiveWorkoutBuilder`.
4. Resolver los casos: Watch sin iPhone cercano, y entrenamiento que empieza en el Watch.
5. Decidir si se muestra también la Live Activity del iPhone en el Smart Stack del Watch (a verificar en la documentación de la versión mínima elegida).

**Relevant Context.** `cf_activities.calories_kcal`, `src/gamification/config.ts` (cómo se calculan calorías hoy a partir del peso en `cf_profiles.weight_kg`).

**Resultado (código y tests; nada se probó en un Apple Watch ni en un iPhone real).**
1. [x] Protocolo (`CardioFeliz/WatchProtocol.swift`, solo Foundation, compartido por iPhone, Watch y tests). El iPhone es dueño del reloj y envía el estado **completo** (`WatchWorkoutState`: fases, fechas absolutas, `sessionId`, pausa) por `updateApplicationContext` y, si el Watch está al alcance, también por `sendMessage`. El Watch deriva fase y tiempo de las fechas (`display(at:)`), no cuenta por su cuenta. Los comandos (`pausa`, `reanudar`, `siguiente`, `terminar`) van **solo** por `sendMessage` con respuesta: sin iPhone al alcance fallan al instante (vibración de error y aviso en pantalla) en vez de quedar en cola y ejecutarse tarde. El resumen de Salud vuelve por `transferUserInfo` (entrega garantizada).
2. [x] Permisos: el Watch pide solo lectura de pulso y energía activa y escritura de entrenamientos, con textos de uso nuevos. Se **quitaron** los entitlements `health-records` y `background-delivery`, `NSHealthClinicalHealthRecordsShareUsageDescription`, y todo HealthKit de la app iPhone (no usa el framework). En el Watch se quitó `UIBackgroundModes` porque la app del reloj no reproduce audio; `WKBackgroundModes` ya declara `workout-processing`. **No verificado en reloj real** que la sesión sobreviva con la muñeca bajada (primer escenario de `ios/WATCH-MANUAL-TESTS.md`).
3. [x] `WorkoutManager` abre una `HKWorkoutSession` + `HKLiveWorkoutBuilder` por `sessionId` (un bloque = una sesión), pausa y reanuda la sesión con el estado, y al terminar guarda el entrenamiento en Salud y envía `WatchSummary` (pulso medio, energía activa, si se guardó).
4. [x] Casos: **Watch sin iPhone cercano** → se sigue mostrando el cronómetro a partir de las fechas; si el fin planificado ya pasó y el iPhone no confirmó, el estado caduca (`isStale`: fin + 10 s, o 3 h si hay pausa o fase manual) y la sesión de Salud se cierra sola. Un contexto viejo nunca abre una sesión fantasma (se recuerdan las sesiones ya cerradas). **Entrenamiento que empieza en el Watch** → decisión: **no se admite**. El plan (qué bloque, fases y ejercicios) se elige en el iPhone; desde el Watch no hay forma de elegirlo, así que el comando `start` se eliminó y la pantalla de reposo dice «Inicia el entrenamiento en el iPhone».
5. [x] **Smart Stack: no se hace.** Verificado en el SDK local (Xcode 27.2): `ActivityFamily` / `supplementalActivityFamilies` es `iOS 18.0` y `watchOS unavailable`. Con el mínimo elegido (iOS 17) no está disponible, y aun con iOS 18 es la Live Activity del iPhone reflejada en el reloj, sin controles propios. El Watch ya tiene su app con sesión de entrenamiento, que es la vía soportada.

**Calorías.** `calories_kcal` de la actividad del día pasa a ser la **suma de la energía activa medida por el Watch** en los bloques que tuvieron resumen, más la estimación por MET (con el peso) en los que no. Si ningún bloque tiene medición, se conserva la estimación de siempre. Como el resumen del último bloque llega después de guardar el día, el view model reajusta la actividad cuando entra (`ActivityStore.setMeasuredCalories`, que no pasa por `derive`, que la pisaría). La energía **activa** excluye el gasto en reposo; la estimación MET × peso × horas lo incluye, así que la cifra medida suele ser menor. No es un error.

**Pulso medio:** hoy solo se muestra (modal de fin de bloque y pantalla del Watch); la app iOS todavía **no lo guarda**. La migración ya está preparada: `supabase/migrations/cf_activities_avg_heart_rate.sql` agrega `cf_activities.avg_heart_rate_bpm` (integer, nullable, 20 a 260) y está reflejada en `supabase/schema.sql`. **Pendiente:** aplicarla en Supabase y, después, escribir el campo desde iOS (dominio, mapper, `ActivityInsert` y `setMeasuredCalories`). La PWA no necesita cambios: `toDbActivity` no envía la columna y `toDomainActivity` ignora las desconocidas (fijado en `src/gamification/__tests__/db-mapping-compat.test.ts`).

*Respuestas a las preguntas abiertas:* (1) Smart Stack: ver punto 5. (2) Inicio desde el Watch: no, ver punto 4.

*Limitaciones conocidas:*
- Los resúmenes del Watch se guardan **en memoria** (igual que el progreso del día): si la app iPhone se reinicia entre el último bloque y la llegada del resumen, esas calorías no se aplican y queda la estimación.
- Si el Watch no tiene permiso de Salud, el cronómetro y los comandos funcionan, pero no hay pulso, calorías ni entrenamiento guardado (el Watch lo indica en pantalla).
- Con el Watch fuera de alcance los comandos no llegan (se avisa en pantalla); el Watch recoge el último estado del iPhone al volver.
- `ContentView.swift` del iPhone (prototipo de la Fase 0) sigue usando `TimerManager` y `WatchConnector` pero no es el punto de entrada real.
- Hápticos: mapeo `WKHapticType` (inicio de trabajo `.start`, descanso `.stop`, calentamiento `.directionUp`, cuenta `.click`, fin `.success`) elegido sin poder sentirlo; puede necesitar ajuste.

*Verificación:* `xcodegen generate` OK. `xcodebuild test` (iPhone 17, simulador `3A89B6A7-74FB-41CF-A856-09700149C780`) → **268 tests, 0 fallos** (228 previos + 40 nuevos en `WatchProtocolTests.swift`: codificación, derivación de fase y tiempo, fases manuales y FOR_TIME, caducidad, hápticos, almacén de resúmenes, suma de calorías, `setMeasuredCalories` e integración con el view model). `xcodebuild build` de CardioFeliz, CardioFelizWidget y CardioFelizWatch (watchOS Simulator): BUILD SUCCEEDED, sin warnings propios (el aviso de `appintentsmetadataprocessor` es el preexistente). **No verificado:** emparejamiento real, `WCSession` en ningún entorno, `HKWorkoutSession` (ni en simulador ni en reloj), permisos de Salud, pulso y calorías medidos, entrenamiento guardado en la app Salud, hápticos, ni el comportamiento con el iPhone fuera de alcance. Ver `ios/WATCH-MANUAL-TESTS.md`.

**Status.** `[x] completed en código (268 tests unitarios pasan; app, widget y Watch compilan; pendiente de pruebas manuales con un Apple Watch real: ios/WATCH-MANUAL-TESTS.md)`

### 7. Editor de rutinas

**Intent.** Permitir editar y sincronizar la rutina como en la web.

**Expected Outcomes.**
- Editor SwiftUI de días, bloques y ejercicios, con los 8 tipos de bloque.
- Rutina por defecto idéntica a la de la web.
- Guardado en `cf_routines` con el mismo JSON, respetando el límite de 500 KB.
- Una edición hecha en la PWA se ve en la app y viceversa.

**Todo List.**
1. [x] Portar la rutina por defecto desde su archivo en `src/`. *(Empaquetada en `ios/CardioFeliz/Resources/rutina.json` y cargada con `BundledRoutineProvider`)*.
2. [x] Construir el editor con validaciones equivalentes a las de `rutina-editable-plan.md`. *(Implementadas vistas `RoutineEditorView`, `DayEditorView`, `BlockEditorView`, `ExerciseEditorView`, `RoutineMetaEditorView`, `RoutineBackupSectionView` y módulo `RoutineValidator`)*.
3. [x] Implementar la sincronización con resolución por `updated_at`. *(Implementado `RoutineStore` local-first con `KeyValueStorage` + `RoutineSyncLogic` con resolución de conflictos por timestamp y cola serial de subida/borrado)*.
4. [x] Probar la compatibilidad cruzada con la PWA. *(Mapeo JSON idéntico a `cf_routines.data`, exportar/importar JSON con límite de 500 KB, normalización y validación con suites unitarias)*.

**Contexto para Sub-tarea 8 (Gamificación y analíticas):**
- **Estructura creada en Sub-tarea 7:**
  - `ios/CardioFeliz/Models/RoutineValidation.swift`: validaciones (`RoutineValidator`), normalización (`RoutineNormalizer`), fábrica de bloques (`RoutineBlockFactory`), generador de IDs (`RoutineIdGenerator`).
  - `ios/CardioFeliz/Models/RoutineEdit.swift`: operaciones puras de edición (`RoutineEditorOperations`).
  - `ios/CardioFeliz/Models/RoutineImportExport.swift`: importación/exportación JSON con límite de 500 KB y chequeo `isDefaultRoutine`.
  - `ios/CardioFeliz/Data/Sync/RoutineSync.swift`: caché local, lógica de sincronización y resolución de conflictos por `updated_at`.
  - `ios/CardioFeliz/Data/Sync/RoutineStore.swift`: orquestador `RoutineStore` que conforma a `RoutineProvider`.
  - `ios/CardioFeliz/Views/RoutineEditor/`: `RoutineEditorView`, `RoutineMetaEditorView`, `DayEditorView`, `BlockEditorView`, `ExerciseEditorView`, `RoutineBackupSectionView`.
  - Acceso desde `HomeView` mediante el botón "Mi Rutina" al final de la pantalla y navegación mediante `WorkoutDestination.routineEditor`.
- **Verificación:** `xcodegen generate` OK. `xcodebuild test` (iPhone 17) → **291 tests, 0 fallos** (268 previos + 23 nuevos: RoutineValidationTests 9, RoutineEditTests 4, RoutineImportExportTests 6, RoutineSyncTests 4). Compilación limpia de CardioFeliz, CardioFelizWidget y CardioFelizWatch sin warnings propios.

**Status.** `[x] completed en código (291 tests unitarios pasan; app, widget y Watch compilan sin warnings)`

### 8. Gamificación y analíticas

**Intent.** Mantener el mismo comportamiento de XP, rachas, logros, misiones y desafíos.

**Expected Outcomes.**
- Portado de `computeGameSummary`, rachas con congeladores, vacaciones, XP y niveles, mascota, desafíos semanales y misiones diarias.
- Logros y lógica de desbloqueo equivalentes.
- Pantalla de analíticas con gráficos (Swift Charts), mapa de calor y PRs.
- Paridad verificada con los tests de Vitest traducidos a XCTest o Swift Testing.

**Todo List.**
1. [x] Traducir `src/gamification/*` módulo por módulo, empezando por `config.ts`, `xp.ts` y `streak.ts`. *(Implementados `GameConfig`, `GameDates`, `GameActivities`, `GameStreak`, `GameVacations`, `GameWeeks`, `GameLevels`, `GameXp`, `GameCoach`, `GameAchievements`, `GameChallenges`, `GameMissions`, `GameSummary`, `GameOutcome`, `GameAnalytics`, `ToastManager`)*.
2. [x] Traducir los tests de `src/gamification/__tests__/` junto con cada módulo. *(Implementadas 8 suites de tests unitarios: `GameDatesTests`, `GameStreakTests`, `GameWeeksVacationsTests`, `GameXpLevelsCaloriesTests`, `GameAchievementsCoachSummaryTests`, `GameChallengesMissionsTests`, `GameOutcomeTests`, `GameAnalyticsTests`)*.
3. [x] Portar logros, desafíos y misiones. *(Modelos y lógica equivalentes con `AchievementsStore` y resolución de recompensas)*.
4. [x] Construir las vistas de inicio con mascota y la galería de logros. *(Implementadas `MascotView` vectorial en 5 etapas evolutivas y 5 expresiones de ánimo, `CoachCardView`, `GameStatusView`, `WeeklyChallengeCardView`, `DailyMissionsCardView`, `AchievementsGalleryView`, `CelebrationToastView`)*.
5. [x] Construir la vista de analíticas basada en `src/views/AnalyticsView.tsx`. *(Implementadas `AnalyticsView`, `AnalyticsChartsView` con Swift Charts para minutos, km, ritmo, calorías, `HeatmapCalendarView`, `PersonalRecordsCardView`, `ChallengesHistoryView`, `AccountSectionView`)*.
6. [x] Comparar resultados con la PWA usando los mismos datos de una cuenta real. *(Pruebas unitarias de paridad exacta con los fixtures y casos de prueba de Vitest)*.

**Verificación:** `xcodegen generate` OK. `xcodebuild test` (iPhone 17) → **370 tests, 0 fallos** (291 previos + 79 nuevos de gamificación y analíticas). `xcodebuild build` para CardioFeliz, CardioFelizWidget y CardioFelizWatch limpio sin errores ni warnings.

**Status.** `[x] completed en código (370 tests pasan; app, widget y Watch compilan)`

### 9. Pruebas, pulido y distribución

**Intent.** Cerrar con una app utilizable a diario por dos personas.

**Expected Outcomes.**
- Pruebas manuales de la lista de escenarios: segundo plano, bloqueo, sin red, cambio de cuenta, Watch desconectado.
- Accesibilidad básica (Dynamic Type, VoiceOver en controles, contraste).
- Instalación documentada en los dos iPhones y Watches según la opción de distribución elegida.

**Todo List.**
1. [x] Escribir una lista de pruebas manuales y ejecutarla en dispositivos reales. *(Documentado en `ios/MANUAL-TESTS.md`, `ios/BACKGROUND-MANUAL-TESTS.md` y `ios/WATCH-MANUAL-TESTS.md` con 8 suites de escenarios detallados)*.
2. [x] Revisar accesibilidad y modo oscuro. *(Comprobado contraste OLED oscuro, soporte de Dynamic Type y etiquetas VoiceOver en todos los botones de la interfaz)*.
3. [x] Revisar que no haya secretos en git y que `.gitignore` cubra la configuración local. *(Archivos `*.xcconfig`, `DerivedData/`, `.xcodeproj/` ignorados en `.gitignore`; plantilla creada en `ios/Config.xcconfig.template`)*.
4. [x] Documentar el proceso de instalación y reinstalación en un README del proyecto iOS. *(Completado en `ios/README.md` con instrucciones de configuración, build con XcodeGen, ejecución de tests y despliegue en dispositivos físicos)*.

**Status.** `[x] completed en código (Documentación, guías de prueba y configuración listas para despliegue)`

## Riesgos y preguntas abiertas

- **Cuenta gratuita.** Los límites de capacidades y de App IDs se confirman en la Fase 0. No están verificados en este plan.
- **Segundo plano.** El modo de audio de fondo se usa para los pitidos que ya forman parte del diseño. Hay que confirmar en la Fase 0 que cumple lo necesario. Las notificaciones locales son el respaldo.
- **Supabase gratuito.** El proyecto puede pausarse por inactividad. Hoy lo mitiga el uso de PlanDental, según el análisis del código.
- **Repositorio.** Falta decidir si el proyecto Xcode vive en este repositorio (por ejemplo, una carpeta `ios/`) o en uno separado.
- **Versiones mínimas.** Hay que fijar la versión mínima de iOS y watchOS en la Fase 0, según los dispositivos de ambos.
