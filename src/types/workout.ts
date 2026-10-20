export type TipoBloque =
  | 'EMOM'
  | 'AMRAP'
  | 'TRISERIE'
  | 'DENSITY'
  | 'FOR_TIME'
  | 'TABATA'
  | 'FINISHER'
  | 'HIIT_INTERVALS';

export interface EjercicioEMOM {
  minuto: number;
  detalle: string;
}

export interface EjercicioGenerico {
  detalle: string;
  /** Duración en segundos para pasos con temporizador automático (p. ej. descansos o intervalos). */
  segundos?: number;
}

export type Ejercicio = EjercicioEMOM | EjercicioGenerico;

export interface BloqueBase {
  /** Id estable del bloque. No cambia al editar nombre ni tipo. */
  id?: string;
  tipo: TipoBloque;
  nombre: string;
  duracion_minutos?: number;
  cap_minutos?: number;
  descanso_entre_rondas?: string;
  estructura?: string;
  /** Número de rondas configurables (p. ej. Triserie, Density, Finisher). */
  rondas?: number;
  /** Descanso entre rondas en segundos (reemplaza a `descanso_entre_rondas` como string). */
  descanso_seg?: number;
  /** Duración del intervalo de trabajo en segundos (HIIT_INTERVALS, Finisher). */
  trabajo_seg?: number;
  /** Duración del descanso Tabata en segundos. */
  descanso_tabata_seg?: number;
  ejercicios: Ejercicio[];
}

export interface BloqueEMOM extends BloqueBase {
  tipo: 'EMOM';
  duracion_minutos: number;
  ejercicios: EjercicioEMOM[];
}

export interface BloqueAMRAP extends BloqueBase {
  tipo: 'AMRAP';
  duracion_minutos: number;
  ejercicios: EjercicioGenerico[];
}

export interface BloqueTriserie extends BloqueBase {
  tipo: 'TRISERIE';
  descanso_entre_rondas?: string;
  ejercicios: EjercicioGenerico[];
}

/** Density: igual que Triserie en timers; se separa como tipo propio para la UI. */
export interface BloqueDensity extends BloqueBase {
  tipo: 'DENSITY';
  ejercicios: EjercicioGenerico[];
}

export interface BloqueForTime extends BloqueBase {
  tipo: 'FOR_TIME';
  cap_minutos: number;
  ejercicios: EjercicioGenerico[];
}

export interface BloqueTabata extends BloqueBase {
  tipo: 'TABATA';
  estructura?: string;
  ejercicios: EjercicioGenerico[];
}

export interface BloqueFinisher extends BloqueBase {
  tipo: 'FINISHER';
  ejercicios: EjercicioGenerico[];
}

/** HIIT_INTERVALS: igual que Finisher en timers; se separa como tipo propio para la UI. */
export interface BloqueHiitIntervals extends BloqueBase {
  tipo: 'HIIT_INTERVALS';
  ejercicios: EjercicioGenerico[];
}

export type Bloque =
  | BloqueEMOM
  | BloqueAMRAP
  | BloqueTriserie
  | BloqueDensity
  | BloqueForTime
  | BloqueTabata
  | BloqueFinisher
  | BloqueHiitIntervals;

export interface DiaEntrenamiento {
  id: string;
  nombre: string;
  ubicacion: string;
  calentamiento: string;
  /** Duración del calentamiento en minutos. Si está definido, se muestra un timer. */
  calentamiento_minutos?: number;
  bloques: Bloque[];
}

export interface RutinaData {
  usuario: string;
  edad: number;
  objetivo: string;
  dias_entrenamiento: DiaEntrenamiento[];
}
