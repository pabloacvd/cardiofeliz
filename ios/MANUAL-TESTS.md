# Guía y Lista de Pruebas Manuales de CardioFeliz iOS

Este documento define la batería exhaustiva de pruebas manuales requeridas para validar la app CardioFeliz en dispositivos físicos (iPhone y Apple Watch) antes de su uso diario en producción.

---

## Índice de Suites de Prueba
1. [Autenticación y Gestión de Cuentas](#1-autenticación-y-gestión-de-cuentas)
2. [Entrenamiento y Temporizadores en Vivo](#2-entrenamiento-y-temporizadores-en-vivo)
3. [Segundo Plano, Audio y Live Activities](#3-segundo-plano-audio-y-live-activities)
4. [Sincronización con Apple Watch y HealthKit](#4-sincronización-con-apple-watch-y-healthkit)
5. [Modo Sin Conexión y Sincronización](#5-modo-sin-conexión-y-sincronización)
6. [Editor de Rutinas y Compatibilidad Cruzada](#6-editor-de-rutinas-y-compatibilidad-cruzada)
7. [Gamificación, Mascota y Analíticas](#7-gamificación-mascota-y-analíticas)
8. [Accesibilidad, Dynamic Type y Modo Oscuro](#8-accesibilidad-dynamic-type-y-modo-oscuro)

---

## 1. Autenticación y Gestión de Cuentas

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 1.1 | Login con credenciales válidas | Ingresar email y password de una cuenta existente en Supabase. | Inicia sesión de inmediato, descarga el perfil, rutina y actividades en caché local. | [ ] |
| 1.2 | Login con credenciales incorrectas | Ingresar contraseña errónea. | Muestra mensaje de error claro sin exponer trazas internas. | [ ] |
| 1.3 | Persistencia de sesión tras reinicio | Cerrar la app forzadamente y volver a abrirla. | Mantiene la sesión activa (`signedIn`) y entra directamente a la pantalla principal sin parpadeos. | [ ] |
| 1.4 | Cambio de cuenta (Usuario A -> Usuario B) | Cerrar sesión desde la barra superior o sección Cuenta y loguear con otro usuario. | Los datos en pantalla (rutina, historial, rachas, XP, peso, vacaciones) se actualizan a los del nuevo usuario. | [ ] |

---

## 2. Entrenamiento y Temporizadores en Vivo

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 2.1 | Flujo completo de un día de entrenamiento | Seleccionar un día en Home, realizar el calentamiento guiado (o saltar), e iniciar los bloques. | Avanza por cada bloque según su tipo (Tabata, EMOM, AMRAP, Triserie, Finisher, For Time). | [ ] |
| 2.2 | Cuenta regresiva y tonos de audio | Observar los últimos 3 segundos de cualquier fase. | Suenan los pitidos 3, 2, 1 y el tono agudo de cambio de fase con sintetizador nativo de audio. | [ ] |
| 2.3 | Pausa y reanudación en iPhone | Tocar botón de pausa a mitad de una fase de trabajo y reanudar 5 segundos después. | El cronómetro se congela exactamente y reanuda sin desfases de tiempo ni pérdida de segundos. | [ ] |
| 2.4 | Modal de finalización de bloque y día | Completar el último bloque de un día. | Abre el modal de victoria, reproduce fanfarria sonora, muestra XP ganado y logros desbloqueados. | [ ] |

---

## 3. Segundo Plano, Audio y Live Activities

*Detalles ampliados en [BACKGROUND-MANUAL-TESTS.md](BACKGROUND-MANUAL-TESTS.md).*

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 3.1 | Bloqueo de pantalla durante bloque | Iniciar un bloque y bloquear el iPhone. | El audio de fondo mantiene los tonos sincronizados y la pantalla de bloqueo / Dynamic Island actualiza la cuenta regresiva. | [ ] |
| 3.2 | Mezcla con música de fondo | Reproducir Spotify / Apple Music e iniciar un entrenamiento. | La música de fondo continúa reproduciéndose (categoría `.playback` con opción `.mixWithOthers`). | [ ] |
| 3.3 | Control desde Live Activity | Pausar y reanudar desde los botones de la Live Activity en Dynamic Island o pantalla de bloqueo. | El entrenamiento responde inmediatamente sin necesidad de desbloquear o abrir la app. | [ ] |
| 3.4 | Llamada o interrupción de audio | Recibir una llamada telefónica durante el entrenamiento y colgar. | La sesión se recupera tras la llamada sin reiniciar el progreso. | [ ] |

---

## 4. Sincronización con Apple Watch y HealthKit

*Detalles ampliados en [WATCH-MANUAL-TESTS.md](WATCH-MANUAL-TESTS.md).*

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 4.1 | Permisos de HealthKit | Abrir la app en el Watch y aceptar lectura de frecuencia cardíaca, energía activa y escritura de entrenamientos. | Solo solicita permisos de salud pertinentes para el entrenamiento. | [ ] |
| 4.2 | Visualización en pantalla Always-On del Watch | Iniciar bloque en iPhone con el Watch en la muñeca y bajar el brazo. | La app de WatchOS sigue activa en segundo plano, midiendo pulso y actualizando tiempo con hápticos. | [ ] |
| 4.3 | Comandos bidireccionales Watch <-> iPhone | Pausar, reanudar o avanzar fase desde el Apple Watch. | El iPhone refleja el cambio al instante y viceversa. | [ ] |
| 4.4 | Guardado de entrenamiento en Apple Health | Terminar un bloque o día completo con el Watch. | Se guarda la sesión de entrenamiento «Cardio mixto» en la app Salud con pulso medio y calorías medidas. | [ ] |

---

## 5. Modo Sin Conexión y Sincronización

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 5.1 | Registrar entrenamiento en Modo Avión | Activar Modo Avión, completar un entrenamiento o registrar una corrida rápida. | La actividad se guarda de inmediato en la base de datos local (SwiftData) y marca estado «1 pendiente». | [ ] |
| 5.2 | Recuperación de conexión y auto-sync | Desactivar Modo Avión. | El gestor de sincronización detecta la red, sube la actividad a Supabase y pasa a «Sincronizado». | [ ] |
| 5.3 | Registro rápido de descanso activo o corrida | Usar la tarjeta de «Registro rápido» en Home con y sin conexión. | Guarda los minutos, kilómetros o sensación térmica sin bloquear la interfaz. | [ ] |

---

## 6. Editor de Rutinas y Compatibilidad Cruzada

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 6.1 | Editar bloques y ejercicios en iPhone | Modificar tiempos de un bloque o agregar un ejercicio desde «Mi Rutina». | La rutina local se actualiza y se sincroniza en la tabla `cf_routines` con su nuevo `updated_at`. | [ ] |
| 6.2 | Compatibilidad PWA -> iOS | Editar la rutina en la web PWA y abrir la app en el iPhone. | La app descarga la última versión editada sin conflictos. | [ ] |
| 6.3 | Exportar e importar JSON de respaldo | Exportar la rutina como JSON y probar importarla. | Valida la estructura, respeta el límite de 500 KB y aplica la rutina correctamente. | [ ] |
| 6.4 | Restaurar rutina por defecto | Seleccionar «Restaurar rutina inicial». | Vuelve a cargar la rutina empaquetada de `rutina.json` sin errores. | [ ] |

---

## 7. Gamificación, Mascota y Analíticas

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 7.1 | Cálculo de racha y congeladores | Registrar entrenamientos en días consecutivos o usar un congelador en día omitido. | La racha se incrementa adecuadamente; si se omite un día con hielos disponibles, la racha se protege. | [ ] |
| 7.2 | Modo Vacaciones | Activar vacaciones desde la tarjeta de estado o sección cuenta con rango de fechas. | Las rachas quedan en pausa («Pausada por vacaciones»), el entrenador muestra mensaje temático y no se pierden días. | [ ] |
| 7.3 | Desafío semanal y misiones diarias | Completar las misiones del día o avanzar el desafío semanal. | Las barras de progreso se llenan y otorgan el bonus de XP configurado. | [ ] |
| 7.4 | Galería de logros y Toasts flotantes | Desbloquear un nuevo logro. | Aparece el Toast de celebración flotante y el logro se muestra desbloqueado en la galería. | [ ] |
| 7.5 | Gráficos de analíticas y mapa de calor | Abrir la pantalla de Analíticas y cambiar entre Semana, Mes y Todo. | Renderiza los gráficos nativos de Swift Charts (minutos, km, ritmo, calorías, mapa de calor mensual). | [ ] |

---

## 8. Accesibilidad, Dynamic Type y Modo Oscuro

| # | Escenario | Procedimiento | Resultado Esperado | OK |
|---|-----------|---------------|--------------------|----|
| 8.1 | Compatibilidad con Modo Oscuro | Alternar el tema del sistema entre Claro y Oscuro. | La app mantiene una estética OLED oscura de alto contraste sin textos ilegibles. | [ ] |
| 8.2 | Tamaño de texto dinámico (Dynamic Type) | Aumentar el tamaño de letra en Ajustes > Accesibilidad > Tamaño del texto. | Los textos de la interfaz escalan correctamente sin desbordes ni botones truncados. | [ ] |
| 8.3 | Lector de pantalla VoiceOver | Activar VoiceOver y navegar por Home, controles del temporizador y analíticas. | Todos los botones interactivos (silenciar, sincronizar, volver, controles de tiempo) cuentan con etiquetas descriptivas accesibles. | [ ] |
