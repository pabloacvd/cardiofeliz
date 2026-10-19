-- CardioFeliz - Supabase Schema
--
-- Este esquema comparte el proyecto Supabase (y por lo tanto auth.users) con PlanDental.
-- REGLAS DE AISLAMIENTO:
--   * Todos los objetos propios usan el prefijo `cf_` (tablas, funciones, índices, políticas).
--   * Este script NO modifica, lee ni referencia ninguna tabla, función, trigger o política de PlanDental.
--   * Solo se referencia auth.users (login compartido: <usuario>@app.local + contraseña).
--   * Es idempotente: se puede ejecutar más de una vez.

begin;

-- ============================================================================
-- TABLAS
-- ============================================================================

-- 1. cf_profiles: datos propios de CardioFeliz por usuario (no reemplaza public.profiles de PlanDental)
create table if not exists public.cf_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  weight_kg numeric(5, 2) check (weight_kg is null or (weight_kg >= 20 and weight_kg <= 300)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. cf_activities
create table if not exists public.cf_activities (
  id uuid primary key, -- UUID generado en cliente para idempotencia / local-first
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('workout_day', 'run', 'active_rest')),
  occurred_on date not null, -- Fecha local YYYY-MM-DD
  started_at timestamptz,
  duration_seconds integer not null check (duration_seconds >= 0),
  day_id text check (day_id is null or char_length(day_id) <= 64), -- id de día de la rutina (soporta rutinas por usuario)
  blocks_completed integer check (blocks_completed is null or blocks_completed >= 0),
  rounds_total integer check (rounds_total is null or rounds_total >= 0),
  distance_km numeric(5, 2) check (distance_km is null or distance_km >= 0),
  run_location text check (run_location is null or run_location in ('cinta', 'calle')),
  feeling integer check (feeling is null or (feeling >= 1 and feeling <= 5)),
  calories_kcal numeric(7, 2) check (calories_kcal is null or calories_kcal >= 0),
  xp_earned integer not null default 0 check (xp_earned >= 0),
  created_at timestamptz not null default now()
);

-- 3. cf_achievements
create table if not exists public.cf_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null check (char_length(achievement_id) <= 64),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

-- 4. cf_vacations
create table if not exists public.cf_vacations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  start_on date not null, -- YYYY-MM-DD
  end_on date,           -- YYYY-MM-DD, null mientras el período esté activo
  created_at timestamptz not null default now(),
  constraint cf_vacations_dates_check check (end_on is null or end_on >= start_on)
);

-- 5. cf_routines: rutina personalizada por usuario (si no existe fila, se usa la default de la app)
create table if not exists public.cf_routines (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null check (octet_length(data::text) <= 500000),
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- ÍNDICES
-- ============================================================================

create index if not exists cf_idx_activities_user_occurred
  on public.cf_activities (user_id, occurred_on desc);

create index if not exists cf_idx_vacations_user
  on public.cf_vacations (user_id, start_on desc);

-- Máximo un período de vacaciones activo (end_on is null) por usuario
create unique index if not exists cf_idx_vacations_single_active
  on public.cf_vacations (user_id)
  where end_on is null;

-- ============================================================================
-- updated_at automático (función propia, prefijada)
-- ============================================================================

create or replace function public.cf_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cf_profiles_set_updated_at on public.cf_profiles;
create trigger cf_profiles_set_updated_at
  before update on public.cf_profiles
  for each row execute function public.cf_set_updated_at();

drop trigger if exists cf_routines_set_updated_at on public.cf_routines;
create trigger cf_routines_set_updated_at
  before update on public.cf_routines
  for each row execute function public.cf_set_updated_at();

-- ============================================================================
-- PERMISOS Y ROW LEVEL SECURITY
-- Solo usuarios autenticados, y cada uno únicamente sobre sus propias filas.
-- El rol anónimo (anon) no tiene acceso alguno.
-- ============================================================================

revoke all on public.cf_profiles, public.cf_activities, public.cf_achievements, public.cf_vacations, public.cf_routines from anon;
grant select, insert, update, delete on public.cf_profiles, public.cf_activities, public.cf_achievements, public.cf_vacations, public.cf_routines to authenticated;

alter table public.cf_profiles enable row level security;
alter table public.cf_activities enable row level security;
alter table public.cf_achievements enable row level security;
alter table public.cf_vacations enable row level security;
alter table public.cf_routines enable row level security;

-- Políticas (drop + create para mantener el script idempotente; solo afecta políticas cf_*)
drop policy if exists "cf_profiles_select_own" on public.cf_profiles;
drop policy if exists "cf_profiles_insert_own" on public.cf_profiles;
drop policy if exists "cf_profiles_update_own" on public.cf_profiles;
drop policy if exists "cf_profiles_delete_own" on public.cf_profiles;

create policy "cf_profiles_select_own" on public.cf_profiles
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "cf_profiles_insert_own" on public.cf_profiles
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "cf_profiles_update_own" on public.cf_profiles
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "cf_profiles_delete_own" on public.cf_profiles
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "cf_activities_select_own" on public.cf_activities;
drop policy if exists "cf_activities_insert_own" on public.cf_activities;
drop policy if exists "cf_activities_update_own" on public.cf_activities;
drop policy if exists "cf_activities_delete_own" on public.cf_activities;

create policy "cf_activities_select_own" on public.cf_activities
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "cf_activities_insert_own" on public.cf_activities
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "cf_activities_update_own" on public.cf_activities
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "cf_activities_delete_own" on public.cf_activities
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "cf_achievements_select_own" on public.cf_achievements;
drop policy if exists "cf_achievements_insert_own" on public.cf_achievements;
drop policy if exists "cf_achievements_update_own" on public.cf_achievements;
drop policy if exists "cf_achievements_delete_own" on public.cf_achievements;

create policy "cf_achievements_select_own" on public.cf_achievements
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "cf_achievements_insert_own" on public.cf_achievements
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "cf_achievements_update_own" on public.cf_achievements
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "cf_achievements_delete_own" on public.cf_achievements
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "cf_vacations_select_own" on public.cf_vacations;
drop policy if exists "cf_vacations_insert_own" on public.cf_vacations;
drop policy if exists "cf_vacations_update_own" on public.cf_vacations;
drop policy if exists "cf_vacations_delete_own" on public.cf_vacations;

create policy "cf_vacations_select_own" on public.cf_vacations
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "cf_vacations_insert_own" on public.cf_vacations
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "cf_vacations_update_own" on public.cf_vacations
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "cf_vacations_delete_own" on public.cf_vacations
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "cf_routines_select_own" on public.cf_routines;
drop policy if exists "cf_routines_insert_own" on public.cf_routines;
drop policy if exists "cf_routines_update_own" on public.cf_routines;
drop policy if exists "cf_routines_delete_own" on public.cf_routines;

create policy "cf_routines_select_own" on public.cf_routines
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "cf_routines_insert_own" on public.cf_routines
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "cf_routines_update_own" on public.cf_routines
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "cf_routines_delete_own" on public.cf_routines
  for delete to authenticated using ((select auth.uid()) = user_id);

commit;
