import { useState, useEffect } from 'react';
import { WorkoutSessionLog } from '../types/workout';

const STORAGE_KEYS = {
  COMPLETED_BLOCKS: 'cardiofeliz_completed_blocks',
  COMPLETED_DAYS: 'cardiofeliz_completed_days',
  WORKOUT_LOGS: 'cardiofeliz_workout_logs',
};

export function useWorkoutStorage() {
  const [completedBlocks, setCompletedBlocks] = useState<Record<string, boolean>>(() => {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.COMPLETED_BLOCKS);
      return data ? JSON.parse(data) : {};
    } catch {
      return {};
    }
  });

  const [completedDays, setCompletedDays] = useState<Record<string, boolean>>(() => {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.COMPLETED_DAYS);
      return data ? JSON.parse(data) : {};
    } catch {
      return {};
    }
  });

  const [logs, setLogs] = useState<WorkoutSessionLog[]>(() => {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.WORKOUT_LOGS);
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.COMPLETED_BLOCKS, JSON.stringify(completedBlocks));
    } catch {}
  }, [completedBlocks]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.COMPLETED_DAYS, JSON.stringify(completedDays));
    } catch {}
  }, [completedDays]);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.WORKOUT_LOGS, JSON.stringify(logs));
    } catch {}
  }, [logs]);

  const markBlockComplete = (diaId: string, blockIndex: number, bloqueNombre: string, totalSeconds: number, rounds?: number) => {
    const key = `${diaId}_bloque_${blockIndex}`;
    setCompletedBlocks((prev) => ({ ...prev, [key]: true }));

    const newLog: WorkoutSessionLog = {
      id: `${Date.now()}`,
      diaId,
      bloqueNombre,
      tipoBloque: 'EMOM', // will be recorded with correct block name
      timestamp: Date.now(),
      duracionSegundos: totalSeconds,
      completado: true,
      rondas: rounds,
    };

    setLogs((prev) => [newLog, ...prev.slice(0, 49)]);
  };

  const markDayComplete = (diaId: string) => {
    setCompletedDays((prev) => ({ ...prev, [diaId]: true }));
  };

  const resetAllProgress = () => {
    setCompletedBlocks({});
    setCompletedDays({});
    try {
      localStorage.removeItem(STORAGE_KEYS.COMPLETED_BLOCKS);
      localStorage.removeItem(STORAGE_KEYS.COMPLETED_DAYS);
    } catch {}
  };

  return {
    completedBlocks,
    completedDays,
    logs,
    markBlockComplete,
    markDayComplete,
    resetAllProgress,
  };
}
