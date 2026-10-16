# CardioFeliz PWA - Plan de Implementación

## 1. Visión General del Proyecto
**CardioFeliz** es una Progressive Web App (PWA) de entrenamiento de alta intensidad diseñada para Juli, optimizada para iPhone (iOS Safari / Standalone Home Screen), con interfaz OLED True Black (`#000000`), cronómetros dinámicos especializados por tipo de bloque (EMOM, AMRAP, FOR_TIME, TABATA, TRISERIE), prevención de apagado de pantalla con la **Wake Lock API**, alertas sonoras mediante **Web Audio API** sintetizada, y funcionamiento 100% offline mediante **Service Worker**.

---

## 2. Sub-Tareas de Implementación

### Sub-Tarea 1: Estructura del Proyecto, Configuración de Vite, Tailwind CSS y Tipos
- **Intent**: Inicializar la base del proyecto con React 18 / 19, TypeScript, Vite, Tailwind CSS y tipado estricto para las rutinas.
- **Expected Outcomes**:
  - Proyecto ejecutable con Vite + React + TypeScript + Tailwind CSS.
  - Tipos TypeScript exhaustivos (`types/workout.ts`) que modelan `Rutina`, `DiaEntrenamiento`, `Bloque`, `Ejercicio`, `TipoBloque` (EMOM, AMRAP, FOR_TIME, TABATA, TRISERIE, FINISHER).
  - Archivo `src/data/rutina.json` con la rutina completa de Juli.
- **Todo List**:
  1. Configurar `package.json`, `vite.config.ts`, `tsconfig.json`, `tailwind.config.js`, `postcss.config.js`.
  2. Configurar `index.html` con meta tags específicos para iOS (`viewport-fit=cover`, `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style: black-translucent`, etc.).
  3. Crear `src/types/workout.ts` y poblar `src/data/rutina.json`.
  4. Configurar tema True Black y utilidades de safe-area en `src/index.css`.
- **Status**: `[ ] pending`

---

### Sub-Tarea 2: Núcleo PWA (Manifest, Service Worker, Wake Lock y Audio Engine)
- **Intent**: Proveer capacidades PWA completas, soporte offline total en gimnasio, prevención de bloqueo de pantalla y efectos de sonido nítidos sin dependencias externas de archivos mp3.
- **Expected Outcomes**:
  - `public/manifest.webmanifest` configurado con `display: standalone`, `orientation: portrait`, `background_color: #000000`.
  - Iconos PWA y Apple Touch Icons configurados.
  - `public/sw.js` y registro en `src/main.tsx` para cacheo estático y ejecución offline.
  - Hook `useWakeLock` para mantener la pantalla encendida durante el entrenamiento con reconexión al volver de background (`visibilitychange`).
  - Módulo `src/utils/audio.ts` y hook `useAudioBeeps` con Web Audio API (tonos sinusoidales puros de 880Hz / 440Hz / 1200Hz para cuenta regresiva 3-2-1 y cambio de minuto/fase) con desbloqueo de audio en primer toque.
- **Todo List**:
  1. Crear `manifest.webmanifest` y generar iconos para iOS/PWA.
  2. Implementar `public/sw.js` para precache y offline fallback.
  3. Implementar `src/hooks/useWakeLock.ts`.
  4. Implementar `src/utils/audio.ts` (Web Audio API synth) y `src/hooks/useAudioBeeps.ts`.
- **Status**: `[ ] pending`

---

### Sub-Tarea 3: Pantalla 1 (Home / Selector de Día) y Pantalla 2 (Vista de Bloques)
- **Intent**: Ofrecer acceso instantáneo a las rutinas en 2 toques, con tarjetas gigantes optimizadas para tacto en iPhone y vista colapsable de calentamiento y bloques de entrenamiento.
- **Expected Outcomes**:
  - `HomeView`: Tres botones/tarjetas de ancho completo para Día 1 (Cardio & SkiErg), Día 2 (Mancuernas) y Día 3 (Funcional & Kettlebell), con indicador de ubicación y resumen.
  - `DayDetailView`: Encabezado con navegación rápida, tarjeta destacada de Calentamiento dinámico, lista de bloques (Bloque A, Bloque B, Finisher) con sus detalles de ejercicios y botón de acción directa "Iniciar Bloque / Temporizador".
- **Todo List**:
  1. Crear componentes base `Header`, `DayCard`, `BlockCard`.
  2. Implementar `HomeView` con selección de día y estado en `localStorage`.
  3. Implementar `DayDetailView` con acordeones/tarjetas expandibles y vista previa de ejercicios.
- **Status**: `[ ] pending`

---

### Sub-Tarea 4: Pantalla 3 (Motor de Temporizadores Especializados por Bloque)
- **Intent**: Desarrollar la pantalla de entrenamiento activo con interfaz True Black OLED, tipografía de números gigantes y modos especializados para cada tipo de entrenamiento.
- **Expected Outcomes**:
  - **EMOM Timer**: Cuenta regresiva 60s gigante, tracking de minutos/rondas, alerta sonora en los últimos 3 segundos y al cambio de minuto, visualización del ejercicio del minuto actual y preview del siguiente minuto.
  - **AMRAP Timer**: Cuenta regresiva desde la duración total, checklist táctil de ejercicios y botón de conteo de rondas completadas.
  - **FOR_TIME Timer**: Cronómetro progresivo con Time Cap límite visual, checklist de ejercicios por tachar y botón de "Finalizado".
  - **TABATA Timer**: Intervalos de 20s Trabajo / 10s Descanso por 8 rondas, cambio de color visual (Verde Neón vs Naranja Fuego) y alertas sonoras de inicio/fin de intervalo.
  - **TRISERIE / Repeticiones**: Visualizador de ejercicios por ronda con botón "Siguiente" y temporizador automático de descanso entre rondas (ej. 45 seg).
  - Controles universales: Play/Pausa, Reinicio, Saltar, Salir con confirmación, Mute/Unmute y estado de Wake Lock activo.
- **Todo List**:
  1. Crear `src/hooks/useTimer.ts` con soporte para cuenta regresiva, cuenta progresiva, pausas y callbacks por segundo.
  2. Implementar `EmomTimer.tsx`, `AmrapTimer.tsx`, `ForTimeTimer.tsx`, `TabataTimer.tsx` y `TriserieTimer.tsx`.
  3. Integrar los temporizadores en `ActiveWorkoutView.tsx`.
- **Status**: `[ ] pending`

---

### Sub-Tarea 5: Persistencia, Feedback Háptico, Pantalla de Resumen y Validación
- **Intent**: Registrar el progreso del entrenamiento en `localStorage`, celebrar el fin del bloque con feedback háptico/sonoro y pantalla de felicitaciones, y validar que todo el flujo funcione fluidamente en Safari / iOS.
- **Expected Outcomes**:
  - Guardado del historial y bloques completados en `localStorage`.
  - Pantalla o modal de "¡Bloque Completado!" con tiempo total y botón para continuar al siguiente bloque del día.
  - Verificación de renderizado en viewport de iPhone con soporte de safe area top/bottom.
- **Todo List**:
  1. Implementar hook `useWorkoutHistory` / persistencia en `localStorage`.
  2. Implementar modal/vista de completado de bloque.
  3. Validar builds, Service Worker, y estilos en modo standalone.
- **Status**: `[ ] pending`
