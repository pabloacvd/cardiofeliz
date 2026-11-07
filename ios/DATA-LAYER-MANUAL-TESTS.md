# Pruebas manuales de la capa de datos (sub-tarea 3)

Los tests unitarios (188 en total, sin red ni credenciales) cubren la lógica. Lo que sigue **solo se puede comprobar contra el Supabase real** y con credenciales reales. Hazlo en el simulador y, al final, en el iPhone.

## 0. Preparación

1. En `ios/Config.xcconfig` (ignorado por git) añade estas líneas. Están también en `Config.xcconfig.example`:

   ```
   SLASH = /
   SUPABASE_URL = https:/$(SLASH)TU-PROYECTO.supabase.co
   SUPABASE_ANON_KEY = <clave anon pública>
   ```

   - Usa el mismo valor que `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY` de tu `.env`.
   - En un `.xcconfig`, `//` empieza un comentario. Por eso la URL se escribe `https:/$(SLASH)host`. Si la escribes con `https://` se corta y la app dirá "Sin configurar".
   - Nunca pongas la clave `service_role`.
2. `cd ios && xcodegen generate`, y ejecuta el esquema **CardioFeliz** en el simulador o en el iPhone.
3. Ten a mano la PWA (misma cuenta) y el panel de Supabase (Table Editor → `cf_activities`).

## 1. Estado "sin configurar"

| # | Paso | Resultado esperado |
|---|---|---|
| 1.1 | Quita (o comenta) `SUPABASE_URL` y `SUPABASE_ANON_KEY`, regenera y ejecuta. | Pantalla "Sin configurar". No hay crash ni petición de red. |
| 1.2 | Pon `SUPABASE_URL = http:/$(SLASH)abc.supabase.co` (http, no localhost). | "Sin configurar" (solo se admite HTTPS). |
| 1.3 | Restaura los valores correctos. | Aparece el login. |

## 2. Login

| # | Paso | Resultado esperado |
|---|---|---|
| 2.1 | Entra con tu usuario y contraseña de la PWA (por ejemplo `juli`). | Entra. Arriba aparece tu nombre de usuario y "Sincronizado · N actividades". |
| 2.2 | Cierra la app del todo (deslizar) y ábrela. | Entra sin pedir contraseña (sesión recuperada del Keychain). |
| 2.3 | Pulsa **Salir** y reabre la app. | Vuelve al login. |
| 2.4 | Contraseña incorrecta. | "Usuario o contraseña incorrectos." Sin detalles técnicos. |
| 2.5 | Usuario inexistente. | El mismo mensaje que 2.4 (no se distingue). |
| 2.6 | Usuario con espacios, mayúsculas (`  JULI `). | Entra igual (se normaliza a `juli`). |
| 2.7 | Usuario con caracteres no permitidos (`ju li`, `juli@x.com`) o contraseña vacía. | Mismo mensaje genérico, sin llegar a llamar al servidor. |
| 2.8 | Modo avión, intenta entrar. | "No se pudo conectar…" (mensaje de red, sin detalles). |
| 2.9 | Entra, activa modo avión y reabre la app. | Sigue dentro (sesión local) y marca sin conexión. |

## 3. Lectura de datos creados en la PWA

| # | Paso | Resultado esperado |
|---|---|---|
| 3.1 | En la PWA registra una carrera o un descanso activo. Anota el contador. | — |
| 3.2 | En la app iOS pulsa **Sincronizar**. | El contador de "N actividades" sube en 1. |
| 3.3 | Si tienes más de 1000 actividades (poco probable): compara el contador con `select count(*) from cf_activities where user_id = ...`. | Coinciden (paginación). |

## 4. Alta de actividad offline y sincronización

La pantalla de la sub-tarea 4 aún no existe, así que no hay botón para crear actividades. Para probarlo de punta a punta hay dos caminos:

- **A (recomendado).** Añade temporalmente un botón en `RootView.swift` que llame a `env.activityStore?.addActivity(ActivityDraft(type: .run, occurredOn: ActivityValidation.localDay(Date()), durationSeconds: 600, distanceKm: 2, runLocation: .calle))`. No lo subas al repositorio.
- **B.** Espera a la sub-tarea 4 y repite esta sección con el registro rápido.

| # | Paso | Resultado esperado |
|---|---|---|
| 4.1 | Con red, crea una actividad. | Aparece al instante; el indicador pasa por "Sincronizando…" y vuelve a "Sincronizado". |
| 4.2 | Comprueba en Supabase y en la PWA. | La fila existe con tu `user_id`, `type`, `occurred_on` y `xp_earned = 0` (aún no se calcula XP; ver "discrepancias" en `ios-app-plan.md`). |
| 4.3 | Activa **modo avión**, crea otra actividad. | Se guarda al instante; el indicador dice "1 cambio(s) pendiente(s) de subir". |
| 4.4 | Crea una segunda y una tercera offline. | "3 cambio(s)…" (o los que sean). |
| 4.5 | Cierra la app del todo (sigue en modo avión) y reábrela. | Las actividades siguen ahí y siguen pendientes (cola persistida en SwiftData). |
| 4.6 | Desactiva el modo avión (con la app abierta). | En unos segundos suben solas y pasa a "Sincronizado". |
| 4.7 | Comprueba en Supabase. | Cada actividad aparece **una sola vez**. |
| 4.8 | Repite 4.3 pero deja la app en segundo plano y vuelve a abrirla con red. | Sube al volver a primer plano. |
| 4.9 | Con pendientes y sin red, espera 1–2 minutos con la app abierta. | Reintenta cada minuto (puedes verlo en Console.app, categoría `sync`: `sync failed: ...`). Al volver la red, sube. |

## 5. Idempotencia (sin duplicados)

| # | Paso | Resultado esperado |
|---|---|---|
| 5.1 | Crea una actividad con red muy mala (Network Link Conditioner "Very Bad Network" o corta la red justo al crearla). Repite varias veces **Sincronizar**. | Una sola fila en Supabase por actividad (el `id` es un UUID generado en el cliente y se hace `upsert`). |
| 5.2 | Pulsa **Sincronizar** muchas veces seguidas. | Sin filas duplicadas ni errores. |

## 6. Edición y borrado

Requiere el botón temporal del camino A (o la sub-tarea 4): `updateActivity(id:patch:)` y `removeActivity(id:)`.

| # | Paso | Resultado esperado |
|---|---|---|
| 6.1 | Edita la duración de una actividad ya sincronizada. | Cambia local al instante y en Supabase tras sincronizar. |
| 6.2 | Edita la actividad **estando offline** dos veces y vuelve la red. | Sube una sola vez, con la última versión. |
| 6.3 | Borra una actividad con red. | Desaparece local y en Supabase. |
| 6.4 | Borra una actividad en modo avión; vuelve la red. | No reaparece mientras el borrado está pendiente; después desaparece del servidor. |
| 6.5 | Borra una actividad en la PWA; pulsa **Sincronizar** en iOS. | Desaparece de iOS. |

## 7. Seguridad

| # | Paso | Resultado esperado |
|---|---|---|
| 7.1 | Abre Console.app con el dispositivo/simulador y filtra por subsistema `com.cardiofeliz.app`. Haz login, logout, un fallo de contraseña y una sincronización. | No aparece ninguna contraseña, token, clave, ni email completo. Solo mensajes como `signIn failed: DataLayerError.invalidCredentials`. |
| 7.2 | `git status` en el repositorio. | `ios/Config.xcconfig` no aparece (ignorado). |
| 7.3 | Busca la clave anónima en el repositorio: `grep -rn "<tu clave>" . --exclude-dir=node_modules --exclude=Config.xcconfig --exclude=.env`. | Sin resultados. |
| 7.4 | Con dos cuentas (la tuya y la de tu esposa), inicia sesión con una, sal, y entra con la otra. | Cada una ve solo sus actividades (RLS). La cache local de una no se mezcla con la otra. |

## 8. Hallazgos que debes anotar

Anota aquí lo que no cuadre (qué paso, qué viste, captura de la consola):

- …
