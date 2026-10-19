/**
 * Serializa ejecuciones de una tarea asíncrona sin perder pedidos.
 *
 * - Si la tarea no está corriendo, la ejecuta.
 * - Si ya está corriendo, no lanza una segunda en paralelo: marca que hay que repetirla
 *   apenas termine y devuelve la promesa de la ejecución en curso.
 * - La promesa devuelta se resuelve cuando terminaron la ejecución en curso y todas las
 *   repeticiones pedidas mientras corría.
 */
export function createSerialRunner(task: () => Promise<void>): () => Promise<void> {
  let inFlight: Promise<void> | null = null;
  let rerun = false;

  return function run(): Promise<void> {
    if (inFlight) {
      rerun = true;
      return inFlight;
    }

    inFlight = (async () => {
      try {
        do {
          rerun = false;
          await task();
        } while (rerun);
      } finally {
        inFlight = null;
      }
    })();

    return inFlight;
  };
}
