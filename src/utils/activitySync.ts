import type { Activity } from '../types/gamification';

/** Ordena de la actividad más reciente a la más antigua (desempate estable por id). */
export function sortActivities(activities: readonly Activity[]): Activity[] {
  return [...activities].sort((a, b) =>
    a.occurredOn === b.occurredOn ? (a.id < b.id ? 1 : -1) : a.occurredOn < b.occurredOn ? 1 : -1,
  );
}

/**
 * Combina el historial remoto con el local.
 * - El servidor es la fuente de verdad para lo ya sincronizado.
 * - Las actividades locales todavía pendientes de subir se conservan (y ganan ante el mismo id).
 * Resultado ordenado de la más reciente a la más antigua.
 */
export function mergeRemoteActivities(
  local: readonly Activity[],
  remote: readonly Activity[],
  pendingIds: ReadonlySet<string>,
): Activity[] {
  const byId = new Map<string, Activity>();
  for (const a of remote) byId.set(a.id, a);
  for (const a of local) {
    if (pendingIds.has(a.id)) byId.set(a.id, a);
  }
  return sortActivities([...byId.values()]);
}

/** UUID v4 generado en el cliente: es el id idempotente de la actividad (upsert sin duplicados). */
export function newActivityId(): string {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
