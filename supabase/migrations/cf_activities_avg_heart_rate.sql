-- CardioFeliz - Migración: cf_activities.avg_heart_rate_bpm
--
-- Agrega el pulso medio (latidos por minuto) medido por el Apple Watch durante el entrenamiento.
-- Es opcional: las filas existentes y las actividades hechas sin Watch (o desde la PWA) quedan en null.
--
-- Compatibilidad con la PWA (sin cambios de código necesarios):
--   * La columna es nullable y sin default, así que los inserts/upserts actuales de la PWA siguen válidos.
--   * La PWA hace upsert con `columns=` limitado a las claves que envía (toDbActivity), y esa lista no
--     incluye esta columna: editar una actividad desde la PWA NO borra el pulso guardado desde iOS.
--   * La PWA lee con select('*') y toDomainActivity ignora las columnas que no conoce.
--
-- Idempotente: se puede ejecutar más de una vez en el SQL Editor de Supabase.
--
-- REGLAS DE AISLAMIENTO:
--   * Solo toca public.cf_activities (objeto propio de CardioFeliz).
--   * No modifica ni referencia objetos de PlanDental.
--   * Los permisos y las políticas RLS existentes de la tabla cubren la columna nueva.

begin;

alter table public.cf_activities
  add column if not exists avg_heart_rate_bpm integer;

-- Rango fisiológico razonable; coincide con el filtro que aplica la app iOS (20 a 260).
alter table public.cf_activities
  drop constraint if exists cf_activities_avg_heart_rate_check;
alter table public.cf_activities
  add constraint cf_activities_avg_heart_rate_check
  check (avg_heart_rate_bpm is null or (avg_heart_rate_bpm >= 20 and avg_heart_rate_bpm <= 260));

commit;

-- Reversión (manual, solo si hace falta; borra los datos de esa columna):
--   alter table public.cf_activities drop constraint if exists cf_activities_avg_heart_rate_check;
--   alter table public.cf_activities drop column if exists avg_heart_rate_bpm;
