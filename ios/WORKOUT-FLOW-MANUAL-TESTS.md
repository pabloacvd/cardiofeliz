# CardioFeliz — Protocolo de Pruebas Manuales: Flujo de Entrenamiento (Sub-tarea 4)

Este documento detalla las pruebas manuales paso a paso para verificar en un iPhone físico las funcionalidades que no pueden validarse al 100% en el simulador (audio en segundo plano con pantalla bloqueada, `isIdleTimerDisabled`, mezcla con música del usuario, retroalimentación táctil y flujo completo de entrenamiento).

---

## 1. Pantalla Encendida (Idle Timer)

### Objetivo
Asegurar que la pantalla no se apague ni se bloquee automáticamente mientras se ejecuta un temporizador activo o el calentamiento, pero que vuelva a la configuración normal del sistema al salir.

### Pasos
1. En el iPhone, ve a **Ajustes > Pantalla y brillo > Bloqueo automático** y configúralo en **30 segundos**.
2. Abre la app CardioFeliz e ingresa a un día de entrenamiento (ej. Día 1).
3. Toca **Iniciar Calentamiento** o entra en un bloque (ej. Bloque A) e inicia el temporizador.
4. Deja el iPhone sobre la mesa sin tocar la pantalla durante 1 minuto.
5. **Resultado esperado:** La pantalla permanece encendida con el brillo habitual, el contador avanza y el indicador verde de pantalla encendida está activo.
6. Toca el botón **Volver** (o confirma salir).
7. Deja el iPhone en la pantalla de detalle del día o Home sin tocarlo durante 35 segundos.
8. **Resultado esperado:** La pantalla se atenúa y se bloquea automáticamente según la configuración del sistema (30 s).

---

## 2. Sonidos Sintetizados PCM y Mezcla de Audio

### Objetivo
Comprobar que los tonos de audio (Go, Rest, Tick, Victory) suenen con volumen nítido, sin latencia, respeten el modo silencio de la app y se mezclen adecuadamente con la música o podcasts que el usuario esté reproduciendo.

### Pasos
1. Abre Spotify, Apple Music o Podcasts y reproduce una canción a volumen medio.
2. Vuelve a CardioFeliz e inicia un bloque Tabata o EMOM.
3. Observa el comportamiento sonoro en los siguientes momentos:
   - **Inicio de trabajo (Go):** Doble tono agudo ascendente (880 Hz -> 1760 Hz). La música se atenúa ligeramente (*ducking*) y vuelve a su volumen normal.
   - **Cuenta atrás (Tick):** Beep corto a los 3, 2 y 1 segundos restantes (880 Hz, 80 ms).
   - **Inicio de descanso (Rest):** Tono grave descendente (440 Hz -> 220 Hz).
   - **Finalización (Victory):** Fanfarria trifónica triunfal (523 Hz -> 659 Hz -> 784 Hz -> 1046 Hz).
4. Toca el botón de **Silencio** (icono de altavoz en la barra superior del temporizador).
5. **Resultado esperado:** El icono cambia a altavoz tachado y no se emiten pitidos ni anuncios de voz, mientras que el temporizador sigue avanzando visualmente.

---

## 3. Audio en Segundo Plano y Pantalla Bloqueada

### Objetivo
Verificar que el motor de audio en segundo plano mantenga vivos los avisos acústicos de cambio de fase incluso cuando la app no está visible o el iPhone está bloqueado con la pantalla apagada.

### Pasos
1. Inicia un bloque Tabata (8 rondas de 20 s trabajo / 10 s descanso).
2. Durante los primeros 10 segundos de la primera ronda, presiona el botón lateral del iPhone para **bloquear la pantalla**.
3. Espera a que pasen los 20 segundos de trabajo.
4. **Resultado esperado:**
   - A los 17, 18 y 19 segundos se escuchan los ticks de cuenta atrás (3, 2, 1).
   - A los 20 segundos suena el tono de descanso (Rest).
   - A los 30 segundos suena el tono de inicio de trabajo (Go).
5. Desbloquea el iPhone y vuelve a la app.
6. **Resultado esperado:** El temporizador se muestra en la ronda y segundo exactos (sin desincronización ni salto de tiempo gracias al cálculo por fechas absolutas).

---

## 4. Flujo de Navegación y Tipos de Temporizador

### Objetivo
Verificar la experiencia de usuario y controles en cada tipo de temporizador:
- **EMOM:** Cuenta regresiva por minuto, visualización del ejercicio activo según el minuto actual, botón Siguiente para saltar de minuto.
- **AMRAP:** Cuenta regresiva del tope de tiempo (ej. 15 min), contador de rondas interactivo (+ / -) y checklist de ejercicios para marcar progreso por vuelta.
- **FOR_TIME:** Cronómetro ascendente hasta el tiempo límite (*time cap*), con botón para completar cuando el usuario finaliza sus repeticiones.
- **TABATA:** Indicador de ronda actual / total (ej. 1/8), alternancia visual clara entre fase de Trabajo (verde) y Descanso (ámbar/azul).
- **TRISERIE / DENSITY:** Fases manuales de trabajo con botón "Siguiente" y descansos cronometrados entre series.
- **FINISHER / HIIT:** Pasos guiados con transiciones automáticas o manuales.

### Pasos
1. Prueba iniciar y pausar cada tipo de bloque.
2. Presiona **Pausa:** el contador se detiene y las animaciones se congelan.
3. Presiona **Reanudar:** el contador continúa exactamente desde el tiempo restante sin perder desfase.
4. Presiona **Siguiente:** el temporizador avanza a la siguiente fase o ejercicio.
5. Intenta salir a mitad de un bloque: debe aparecer el modal de advertencia "¿Detener Entrenamiento? El progreso actual se perderá".

---

## 5. Modal de Cierre y Guardado Local-First

### Objetivo
Validar que al terminar el último bloque de un día (o al tocar "Completar entrenamiento"), se presente el modal de resumen y la actividad se almacene inmediatamente en SwiftData / cola de sincronización.

### Pasos
1. Completa los bloques de un día de entrenamiento (o completa el flujo guiado).
2. Al finalizar el último bloque, se presenta automáticamente el modal **¡Entrenamiento Completado!**.
3. Revisa los datos presentados:
   - **Tiempo total:** Duración real transcurrida en minutos/segundos.
   - **Bloques:** Número de bloques completados vs. totales.
   - **Calorías estimadas:** Cálculo basado en el peso del usuario (o aviso para configurar peso si no está definido).
   - **Selector de sensación:** Selección de emoji / estado (Genial, Bien, Cansado, Agotado).
4. Toca **Guardar Actividad**.
5. **Resultado esperado:**
   - La vista vuelve a Home o al detalle del día.
   - El día muestra su insignia o barra de progreso actualizada (ej. "Completado").
   - La barra de sincronización superior muestra el estado de guardado (en cola o sincronizado con Supabase).

---

## 6. Registro Rápido (QuickLogCard)

### Objetivo
Comprobar el registro rápido de actividades fuera de la rutina guiada (Carrera o Descanso activo).

### Pasos
1. En la pantalla principal (Home), localiza la sección **Registro Rápido**.
2. Toca **Carrera**:
   - Ingresa distancia (ej. `5.2` km), duración (ej. `28` min), lugar (Calle, Cinta, Pista, Sendero) y sensación.
   - Toca **Guardar Carrera**.
   - **Resultado esperado:** Se crea la actividad con calorías calculadas por la velocidad metabólica (`CaloriesEstimator.metForRun`).
3. Toca **Descanso Activo**:
   - Ingresa duración (ej. `30` min) y sensación.
   - Toca **Guardar Descanso**.
   - **Resultado esperado:** Se crea la actividad con MET = 3.0.

---

## 7. Vista y Edición del Peso del Perfil

### Objetivo
Verificar la gestión local-first del peso corporal utilizado para el cálculo calórico.

### Pasos
1. En la barra superior de Home, toca el indicador de peso (ej. `75 kg` o `Configurar peso`).
2. Se abre la hoja de edición de peso.
3. Ingresa un peso válido (ej. `74.5` kg) y presiona **Guardar**.
4. **Resultado esperado:**
   - El nuevo peso se refleja instantáneamente en la interfaz.
   - Si no hay conexión a internet, queda marcado como pendiente y se sube automáticamente cuando vuelva la red.
   - Las actividades futuras calculan sus calorías con el nuevo peso.
5. Intenta ingresar un valor fuera de rango (ej. `15` kg o `450` kg): el botón de guardar se desactiva o rechaza la entrada.
