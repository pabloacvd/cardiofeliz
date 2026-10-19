/**
 * src/utils/routineEdit.ts
 *
 * Funciones puras para manipulación y edición de borradores de rutinas:
 * - Operaciones sobre metadatos (objetivo, edad).
 * - Operaciones sobre días (agregar, actualizar, eliminar, reordenar).
 * - Operaciones sobre bloques (agregar, actualizar, cambiar tipo, duplicar, eliminar, reordenar).
 * - Operaciones sobre ejercicios (agregar, actualizar, eliminar, reordenar).
 * - Utilidades de regeneración de estructura Tabata y renumeración EMOM.
 */

import type {
  Bloque,
  BloqueBase,
  DiaEntrenamiento,
  Ejercicio,
  EjercicioEMOM,
  EjercicioGenerico,
  RutinaData,
  TipoBloque,
} from '../types/workout';
import { generateId, newBloqueDefaults } from './routine';

// ---------------------------------------------------------------------------
// Clonado y comparación
// ---------------------------------------------------------------------------

/** Realiza una copia profunda de la rutina. */
export function cloneRutina(rutina: RutinaData): RutinaData {
  return JSON.parse(JSON.stringify(rutina)) as RutinaData;
}

/** Compara si dos rutinas tienen diferencias en contenido. */
export function hasRoutineChanges(a: RutinaData, b: RutinaData): boolean {
  return JSON.stringify(a) !== JSON.stringify(b);
}

// ---------------------------------------------------------------------------
// Metadatos
// ---------------------------------------------------------------------------

export function updateRoutineMeta(
  rutina: RutinaData,
  patch: { objetivo?: string; edad?: number },
): RutinaData {
  const next = cloneRutina(rutina);
  if (patch.objetivo !== undefined) next.objetivo = patch.objetivo;
  if (patch.edad !== undefined) next.edad = patch.edad;
  return next;
}

// ---------------------------------------------------------------------------
// Estructura Tabata y EMOM
// ---------------------------------------------------------------------------

export function regenerateTabataStructure(
  rondas: number,
  trabajoSeg: number,
  descansoSeg: number,
): string {
  return `${trabajoSeg} seg trabajo / ${descansoSeg} seg descanso x ${rondas} rondas`;
}

export function renumberEmomExercises(ejercicios: Ejercicio[]): EjercicioEMOM[] {
  return ejercicios.map((ej, idx) => ({
    minuto: idx + 1,
    detalle: ej.detalle,
  }));
}

function stripEmomMinutes(ejercicios: Ejercicio[]): EjercicioGenerico[] {
  return ejercicios.map((ej) => {
    const { detalle } = ej;
    const segundos = 'segundos' in ej ? ej.segundos : undefined;
    return segundos !== undefined ? { detalle, segundos } : { detalle };
  });
}

function moveArrayItem<T>(arr: T[], fromIndex: number, toIndex: number): T[] {
  if (fromIndex < 0 || fromIndex >= arr.length || toIndex < 0 || toIndex >= arr.length) {
    return [...arr];
  }
  if (fromIndex === toIndex) return [...arr];
  const copy = [...arr];
  const [item] = copy.splice(fromIndex, 1);
  copy.splice(toIndex, 0, item);
  return copy;
}

// ---------------------------------------------------------------------------
// Días
// ---------------------------------------------------------------------------

export function addDay(rutina: RutinaData): RutinaData {
  const next = cloneRutina(rutina);
  const nextNumber = next.dias_entrenamiento.length + 1;
  const newDayId = `dia_${generateId()}`;
  const defaultBlock = newBloqueDefaults('AMRAP');
  defaultBlock.nombre = 'Bloque A';

  const newDay: DiaEntrenamiento = {
    id: newDayId,
    nombre: `Día ${nextNumber}`,
    ubicacion: 'Gym / Casa',
    calentamiento: '5 min caminata inclinada o trote suave',
    bloques: [defaultBlock],
  };

  next.dias_entrenamiento.push(newDay);
  return next;
}

export function updateDay(
  rutina: RutinaData,
  diaId: string,
  patch: { nombre?: string; ubicacion?: string; calentamiento?: string },
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  if (patch.nombre !== undefined) day.nombre = patch.nombre;
  if (patch.ubicacion !== undefined) day.ubicacion = patch.ubicacion;
  if (patch.calentamiento !== undefined) day.calentamiento = patch.calentamiento;

  return next;
}

export function removeDay(rutina: RutinaData, diaId: string): RutinaData {
  const next = cloneRutina(rutina);
  next.dias_entrenamiento = next.dias_entrenamiento.filter((d) => d.id !== diaId);
  return next;
}

export function moveDay(
  rutina: RutinaData,
  fromIndex: number,
  toIndex: number,
): RutinaData {
  const next = cloneRutina(rutina);
  next.dias_entrenamiento = moveArrayItem(next.dias_entrenamiento, fromIndex, toIndex);
  return next;
}

// ---------------------------------------------------------------------------
// Bloques
// ---------------------------------------------------------------------------

export function addBlock(
  rutina: RutinaData,
  diaId: string,
  tipo: TipoBloque = 'AMRAP',
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const newBlock = newBloqueDefaults(tipo);
  const letter = String.fromCharCode(65 + (day.bloques.length % 26));
  newBlock.nombre = `Bloque ${letter}`;

  day.bloques.push(newBlock);
  return next;
}

export function updateBlock(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  patch: Partial<BloqueBase>,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const blockIndex = day.bloques.findIndex((b) => b.id === bloqueId);
  if (blockIndex === -1) return next;

  const currentBlock = day.bloques[blockIndex];
  const updatedBlock: Bloque = { ...currentBlock, ...patch } as Bloque;

  // Si es Tabata y se modificaron tiempos o rondas, regenerar estructura
  if (updatedBlock.tipo === 'TABATA') {
    const rondas = updatedBlock.rondas ?? 8;
    const trabajo = updatedBlock.trabajo_seg ?? 20;
    const descanso = updatedBlock.descanso_tabata_seg ?? 10;
    updatedBlock.estructura = regenerateTabataStructure(rondas, trabajo, descanso);
  }

  // Si se modificó descanso_seg en Triserie/Density, eliminar el string legacy descanso_entre_rondas
  if (patch.descanso_seg !== undefined && (updatedBlock.tipo === 'TRISERIE' || updatedBlock.tipo === 'DENSITY')) {
    delete updatedBlock.descanso_entre_rondas;
  }

  day.bloques[blockIndex] = updatedBlock;
  return next;
}

export function changeBlockType(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  newTipo: TipoBloque,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const blockIndex = day.bloques.findIndex((b) => b.id === bloqueId);
  if (blockIndex === -1) return next;

  const oldBlock = day.bloques[blockIndex];
  const template = newBloqueDefaults(newTipo);

  // Mantener id, nombre y adaptar ejercicios
  let ejercicios: Ejercicio[] = oldBlock.ejercicios;
  if (newTipo === 'EMOM') {
    ejercicios = renumberEmomExercises(ejercicios);
  } else if (oldBlock.tipo === 'EMOM') {
    ejercicios = stripEmomMinutes(ejercicios);
  }

  const convertedBlock: Bloque = {
    ...template,
    id: oldBlock.id ?? generateId(),
    nombre: oldBlock.nombre,
    ejercicios,
  } as Bloque;

  day.bloques[blockIndex] = convertedBlock;
  return next;
}

export function duplicateBlock(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const blockIndex = day.bloques.findIndex((b) => b.id === bloqueId);
  if (blockIndex === -1) return next;

  const original = day.bloques[blockIndex];
  const copy = JSON.parse(JSON.stringify(original)) as Bloque;
  copy.id = generateId();
  copy.nombre = `${original.nombre} (Copia)`;

  // Insertar justo después del original
  day.bloques.splice(blockIndex + 1, 0, copy);
  return next;
}

export function removeBlock(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  day.bloques = day.bloques.filter((b) => b.id !== bloqueId);
  return next;
}

export function moveBlock(
  rutina: RutinaData,
  diaId: string,
  fromIndex: number,
  toIndex: number,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  day.bloques = moveArrayItem(day.bloques, fromIndex, toIndex);
  return next;
}

// ---------------------------------------------------------------------------
// Ejercicios
// ---------------------------------------------------------------------------

export function addExercise(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  detalle: string = '',
  segundos?: number,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const block = day.bloques.find((b) => b.id === bloqueId);
  if (!block) return next;

  if (block.tipo === 'EMOM') {
    const minuto = block.ejercicios.length + 1;
    (block.ejercicios as EjercicioEMOM[]).push({ minuto, detalle });
  } else {
    const exercise: EjercicioGenerico = { detalle };
    if (segundos !== undefined) exercise.segundos = segundos;
    (block.ejercicios as EjercicioGenerico[]).push(exercise);
  }

  return next;
}

export function updateExercise(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  exerciseIndex: number,
  patch: { detalle?: string; segundos?: number | null },
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const block = day.bloques.find((b) => b.id === bloqueId);
  if (!block || exerciseIndex < 0 || exerciseIndex >= block.ejercicios.length) return next;

  const ej = block.ejercicios[exerciseIndex];
  if (patch.detalle !== undefined) {
    ej.detalle = patch.detalle;
  }

  if (block.tipo !== 'EMOM') {
    const generico = ej as EjercicioGenerico;
    if (patch.segundos === null || patch.segundos === undefined) {
      delete generico.segundos;
    } else {
      generico.segundos = patch.segundos;
    }
  }

  return next;
}

export function removeExercise(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  exerciseIndex: number,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const block = day.bloques.find((b) => b.id === bloqueId);
  if (!block || exerciseIndex < 0 || exerciseIndex >= block.ejercicios.length) return next;

  block.ejercicios.splice(exerciseIndex, 1);

  if (block.tipo === 'EMOM') {
    block.ejercicios = renumberEmomExercises(block.ejercicios);
  }

  return next;
}

export function moveExercise(
  rutina: RutinaData,
  diaId: string,
  bloqueId: string,
  fromIndex: number,
  toIndex: number,
): RutinaData {
  const next = cloneRutina(rutina);
  const day = next.dias_entrenamiento.find((d) => d.id === diaId);
  if (!day) return next;

  const block = day.bloques.find((b) => b.id === bloqueId);
  if (!block) return next;

  if (block.tipo === 'EMOM') {
    const moved = moveArrayItem(block.ejercicios, fromIndex, toIndex);
    block.ejercicios = renumberEmomExercises(moved);
  } else {
    block.ejercicios = moveArrayItem(block.ejercicios, fromIndex, toIndex);
  }

  return next;
}
