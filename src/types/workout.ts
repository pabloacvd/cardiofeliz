export type TipoBloque = 'EMOM' | 'AMRAP' | 'TRISERIE' | 'FOR_TIME' | 'TABATA' | 'FINISHER';

export interface EjercicioEMOM {
  minuto: number;
  detalle: string;
}

export interface EjercicioGenerico {
  detalle: string;
}

export type Ejercicio = EjercicioEMOM | EjercicioGenerico;

export interface BloqueBase {
  tipo: TipoBloque;
  nombre: string;
  duracion_minutos?: number;
  cap_minutos?: number;
  descanso_entre_rondas?: string;
  estructura?: string;
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

export type Bloque =
  | BloqueEMOM
  | BloqueAMRAP
  | BloqueTriserie
  | BloqueForTime
  | BloqueTabata
  | BloqueFinisher;

export interface DiaEntrenamiento {
  id: string;
  nombre: string;
  ubicacion: string;
  calentamiento: string;
  bloques: Bloque[];
}

export interface RutinaData {
  usuario: string;
  edad: number;
  objetivo: string;
  dias_entrenamiento: DiaEntrenamiento[];
}

