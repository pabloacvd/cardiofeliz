# Supabase para CardioFeliz

CardioFeliz **comparte el proyecto Supabase con PlanDental** (`wzxgecdpfpnlzaawdyjx`). Los usuarios y las contraseñas son los mismos: se inicia sesión con `usuario` + contraseña (internamente `<usuario>@app.local`).

## Aislamiento respecto de PlanDental

- Todas las tablas, funciones, índices y políticas propias llevan el prefijo `cf_`.
- [`schema.sql`](./schema.sql) solo referencia `auth.users`. No toca `profiles`, `recipes`, `plans`, etc.
- La app lee `public.profiles` únicamente en modo lectura, para mostrar el nombre de usuario.
- El login anónimo está deshabilitado en el proyecto y CardioFeliz no lo usa.
- El rol `anon` no tiene permisos sobre las tablas `cf_*`. Cada usuario autenticado solo accede a sus propias filas (RLS).

## Tablas

| Tabla | Contenido |
|---|---|
| `cf_profiles` | Peso y nombre para mostrar (por usuario) |
| `cf_activities` | Entrenamientos, corridas y descansos activos |
| `cf_achievements` | Logros desbloqueados |
| `cf_vacations` | Períodos de vacaciones |
| `cf_routines` | Rutina personalizada (por usuario) |

## Aplicar el esquema

El script es idempotente. Con la CLI de Supabase iniciada y el repo vinculado al proyecto:

```bash
supabase db query --linked -f supabase/schema.sql
```

Las migraciones incrementales están en [`migrations/`](./migrations) y también quedan reflejadas en `schema.sql`. Para una base ya creada alcanza con ejecutar la migración nueva, por ejemplo:

```bash
supabase db query --linked -f supabase/migrations/cf_activities_avg_heart_rate.sql
```

`cf_activities_avg_heart_rate.sql` agrega `avg_heart_rate_bpm` (pulso medio del Apple Watch, opcional). No requiere cambios en la PWA: ver el encabezado de la migración.

## Variables de entorno

Creá un archivo `.env` en la raíz (ignorado por git), con los valores de **Project Settings > API**:

```env
VITE_SUPABASE_URL=https://wzxgecdpfpnlzaawdyjx.supabase.co
VITE_SUPABASE_ANON_KEY=<anon key>
```

Se pueden obtener con `supabase projects api-keys --project-ref wzxgecdpfpnlzaawdyjx`. La clave `anon` es pública por diseño. La protección real es RLS. Nunca uses la `service_role` en el frontend.

## Alta de usuarios

Los usuarios se gestionan desde PlanDental (misma tabla `auth.users`). Un usuario nuevo creado allí podrá entrar a CardioFeliz con las mismas credenciales.

## Free tier

Un proyecto gratuito se pausa tras unos 7 días sin actividad. Como comparte proyecto con PlanDental, el uso de cualquiera de las dos apps lo mantiene activo. CardioFeliz es local-first y sigue funcionando sin conexión.
