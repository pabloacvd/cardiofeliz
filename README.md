# CardioFeliz 🏃‍♀️⚡

App de entrenamiento personalizada y seguimiento de hábito (React 18 + Vite + Tailwind CSS + PWA) con sistema de gamificación estilo Duolingo, registro de corridas de un toque, analíticas interactivas y sincronización local-first con Supabase.

---

## Características Principales

1. **Entrenamientos Personalizados**:
   - 3 días de rutina con bloques estructurados (EMOM, AMRAP, For Time, Tabata, Triseries, Finishers).
   - Temporizadores interactivos con sonido y Wake Lock (la pantalla se mantiene encendida).
   - Fin de día detectado cuando todos los bloques son completados.

2. **Registro Rápido "Hoy corrí" & "Descanso activo"**:
   - Registro de 1 toque (30 min por defecto).
   - Sheet para ajustar minutos, km opcionales, cinta/calle, nivel de sensación (1-5) y fecha para registrar actividades pasadas.
   - Cálculo automático de calorías estimadas según el peso corporal del perfil.

3. **Motor de Gamificación**:
   - **Rachas y congeladores**: racha diaria con protección de congeladores (1 cada 5 días de racha, máx. 2) y racha semanal de semanas perfectas (3 entrenos + 2 corridas).
   - **XP y Niveles**: progresión con títulos temáticos (Brasita, Llamita, Fueguito, Fogata, Fénix) y mascota SVG interactiva con estados de ánimo.
   - **Desafíos Semanales y Misiones Diarias**: rotación determinista por semana ISO y misiones adaptativas al estado de la semana.
   - **Modo Vacaciones**: pausa que congela la racha sin consumir congeladores; al regresar activa 3 días de *"¡Hay que recuperar!"* con bonus de XP ×1.5.
   - **Logros e Insignias**: catálogo completo con desbloqueos persistidos y celebración única.
   - **Mensaje del Coach**: mensaje contextual diario al abrir la app con estados de ánimo reactivos.

4. **Analíticas y Progreso**:
   - Ícono de analíticas en el header con carga diferida (`React.lazy` + `recharts`).
   - Selector de rango: **Semana / Mes / Todo**.
   - Gráficos de minutos activos apilados por tipo, km corridos, evolución de ritmo (min/km), calorías semanales y distribución por tipo de actividad (dona).
   - Calendario de constancia (Heatmap mensual estilo GitHub).
   - Récords personales (mejor racha, corrida más larga, mejor ritmo, AMRAP récord, semana récord).
   - Galería de logros con progreso porcentual y fechas de desbloqueo.

5. **Local-First & Multi-dispositivo**:
   - Todo se guarda al instante en `localStorage` (namespaces por usuario) y se sincroniza en segundo plano con Supabase.
   - Cola de sincronización para operar 100% offline en el gimnasio y reintentar automáticamente al recuperar conexión.
   - Indicador discreto de estado de sincronización en el header.
   - Login compartido con PlanDental (mismo proyecto Supabase, tablas aisladas `cf_*`).

---

## Tecnologías

- **Frontend**: React 18, TypeScript, Tailwind CSS, Lucide React, Recharts, canvas-confetti
- **Build & Bundler**: Vite 6 (con chunks optimizados para Supabase y Recharts)
- **Backend & Auth**: Supabase (PostgreSQL con Row Level Security)
- **Testing**: Vitest (160 tests unitarios y de integración)

---

## Configuración y Desarrollo

### 1. Variables de entorno

Crear un archivo `.env` en la raíz (ignorado por git) basado en `.env.example`:

```env
VITE_SUPABASE_URL=https://<tu-proyecto>.supabase.co
VITE_SUPABASE_ANON_KEY=<tu-anon-key>
```

### 2. Comandos

```bash
# Instalar dependencias
npm install

# Iniciar servidor de desarrollo
npm run dev

# Ejecutar tests
npm test

# Compilar para producción (typecheck + minificación)
npm run build
```

---

## Base de Datos (Supabase)

El esquema SQL versionado vive en [`supabase/schema.sql`](supabase/schema.sql) y utiliza 4 tablas aisladas:
- `cf_profiles`: peso y nombre de usuario.
- `cf_activities`: historial de entrenamientos, corridas y descansos activos.
- `cf_achievements`: registro de logros desbloqueados.
- `cf_vacations`: períodos de vacaciones.

Ver [`supabase/README.md`](supabase/README.md) para más detalles sobre la arquitectura compartida y RLS.
