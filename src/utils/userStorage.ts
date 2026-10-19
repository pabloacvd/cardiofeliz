/**
 * Claves de localStorage por usuario.
 * Evita que dos usuarios en el mismo dispositivo mezclen su progreso local.
 */

const LEGACY_NAMES = ['completed_blocks', 'completed_days', 'workout_logs'] as const;
const MIGRATION_FLAG = 'cardiofeliz_legacy_migrated_to';

export function userStorageKey(userId: string, name: string): string {
  return `cardiofeliz_${userId}_${name}`;
}

/**
 * Mueve los datos locales anteriores al login (claves sin usuario) al primer usuario
 * que inicia sesión en este dispositivo. Se ejecuta una sola vez.
 */
export function migrateLegacyStorage(userId: string): void {
  try {
    if (localStorage.getItem(MIGRATION_FLAG)) return;

    for (const name of LEGACY_NAMES) {
      const legacyKey = `cardiofeliz_${name}`;
      const legacyValue = localStorage.getItem(legacyKey);
      const targetKey = userStorageKey(userId, name);
      if (legacyValue !== null && localStorage.getItem(targetKey) === null) {
        localStorage.setItem(targetKey, legacyValue);
      }
      localStorage.removeItem(legacyKey);
    }
    localStorage.setItem(MIGRATION_FLAG, userId);
  } catch {
    // storage no disponible: se opera sin migración
  }
}
