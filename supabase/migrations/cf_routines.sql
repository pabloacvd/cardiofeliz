-- CardioFeliz - Migración: tabla cf_routines
--
-- Agrega la tabla cf_routines para almacenar la rutina personalizada por usuario.
-- Idempotente: se puede ejecutar en el SQL Editor de Supabase sin re-correr todo el esquema.
--
-- REGLAS DE AISLAMIENTO:
--   * Todos los objetos propios usan el prefijo `cf_`.
--   * Solo se referencia auth.users.
--   * No modifica ni referencia objetos de PlanDental.

begin;

-- 1. Tabla cf_routines
create table if not exists public.cf_routines (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null check (octet_length(data::text) <= 500000),
  updated_at timestamptz not null default now()
);

-- 2. Función y trigger para updated_at automático
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

drop trigger if exists cf_routines_set_updated_at on public.cf_routines;
create trigger cf_routines_set_updated_at
  before update on public.cf_routines
  for each row execute function public.cf_set_updated_at();

-- 3. Permisos
revoke all on public.cf_routines from anon;
grant select, insert, update, delete on public.cf_routines to authenticated;

-- 4. Row Level Security y políticas por usuario
alter table public.cf_routines enable row level security;

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
