import type { Activity } from '../types/gamification';
import { userStorageKey } from './userStorage';

const ACTIVITY_TYPES = ['workout_day', 'run', 'active_rest'];

export interface ActivityCache {
  activities: Activity[];
  /** Ids de actividades guardadas localmente que todavía no se subieron a Supabase. */
  pending: string[];
  /** Ids borrados localmente cuyo borrado todavía no se aplicó en Supabase. */
  deleted: string[];
}

function isActivity(value: unknown): value is Activity {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.id === 'string' &&
    typeof v.type === 'string' &&
    ACTIVITY_TYPES.includes(v.type) &&
    typeof v.occurredOn === 'string' &&
    typeof v.durationSeconds === 'number' &&
    typeof v.xpEarned === 'number'
  );
}

function readArray(key: string): unknown[] {
  try {
    const raw = localStorage.getItem(key);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function loadActivityCache(userId: string): ActivityCache {
  const activities = readArray(userStorageKey(userId, 'activities')).filter(isActivity);
  const known = new Set(activities.map((a) => a.id));
  const pending = readArray(userStorageKey(userId, 'activities_pending')).filter(
    (id): id is string => typeof id === 'string' && known.has(id),
  );
  const deleted = readArray(userStorageKey(userId, 'activities_deleted')).filter(
    (id): id is string => typeof id === 'string',
  );
  return { activities, pending, deleted };
}

export function saveActivityCache(userId: string, cache: ActivityCache): void {
  try {
    localStorage.setItem(userStorageKey(userId, 'activities'), JSON.stringify(cache.activities));
    localStorage.setItem(userStorageKey(userId, 'activities_pending'), JSON.stringify(cache.pending));
    localStorage.setItem(userStorageKey(userId, 'activities_deleted'), JSON.stringify(cache.deleted));
  } catch {
    // storage lleno o no disponible: la actividad sigue en memoria y se sube igual
  }
}
