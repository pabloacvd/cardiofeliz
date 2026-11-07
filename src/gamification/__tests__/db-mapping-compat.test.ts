import { describe, expect, it } from 'vitest';
import type { ActivityRow } from '../../types/database';
import { toDbActivity, toDomainActivity } from '../../types/gamification';
import { run } from './helpers';

// Contrato del que depende la compatibilidad con columnas que agrega la app iOS
// (p. ej. cf_activities.avg_heart_rate_bpm, ver supabase/migrations/):
//   * La PWA hace upsert solo con las claves de toDbActivity (supabase-js arma `columns=` con ellas),
//     así que una columna que la PWA no conoce no se toca al editar una actividad.
//   * La PWA lee con select('*'): toDomainActivity debe tolerar columnas extra.

const row: ActivityRow = {
  id: '11111111-1111-4111-8111-111111111111',
  user_id: 'u1',
  type: 'run',
  occurred_on: '2026-03-04',
  started_at: null,
  duration_seconds: 1800,
  day_id: null,
  blocks_completed: null,
  rounds_total: null,
  distance_km: 5,
  run_location: 'calle',
  feeling: 4,
  calories_kcal: 300,
  xp_earned: 40,
  created_at: '2026-03-04T11:00:00Z',
};

describe('compatibilidad con columnas desconocidas de cf_activities', () => {
  it('toDomainActivity ignora columnas extra del servidor', () => {
    const withExtra = { ...row, avg_heart_rate_bpm: 142, columna_futura: 'x' } as ActivityRow;
    const activity = toDomainActivity(withExtra);
    expect(activity.id).toBe(row.id);
    expect(activity.durationSeconds).toBe(1800);
    expect(activity).not.toHaveProperty('avg_heart_rate_bpm');
    expect(activity).not.toHaveProperty('columna_futura');
  });

  it('toDbActivity solo envía las columnas conocidas, sin pulso medio', () => {
    const payload = toDbActivity(run('2026-03-04', { id: row.id }), 'u1');
    expect(Object.keys(payload).sort()).toEqual(
      [
        'blocks_completed',
        'calories_kcal',
        'day_id',
        'distance_km',
        'duration_seconds',
        'feeling',
        'id',
        'occurred_on',
        'rounds_total',
        'run_location',
        'started_at',
        'type',
        'user_id',
        'xp_earned',
      ].sort(),
    );
    expect(payload).not.toHaveProperty('avg_heart_rate_bpm');
  });
});
