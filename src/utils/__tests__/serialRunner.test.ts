import { describe, expect, it } from 'vitest';
import { createSerialRunner } from '../serialRunner';

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}

describe('createSerialRunner', () => {
  it('ejecuta la tarea una vez si nadie la vuelve a pedir', async () => {
    let calls = 0;
    const run = createSerialRunner(async () => {
      calls += 1;
    });
    await run();
    expect(calls).toBe(1);
  });

  it('no corre dos veces en paralelo y repite una vez si se pidió durante la ejecución', async () => {
    let calls = 0;
    let running = 0;
    let maxRunning = 0;
    const gates = [deferred(), deferred()];

    const run = createSerialRunner(async () => {
      const gate = gates[calls];
      calls += 1;
      running += 1;
      maxRunning = Math.max(maxRunning, running);
      await gate.promise;
      running -= 1;
    });

    const first = run();
    const second = run();
    const third = run();

    gates[0].resolve();
    await Promise.resolve();
    gates[1].resolve();
    await Promise.all([first, second, third]);

    expect(calls).toBe(2);
    expect(maxRunning).toBe(1);
  });

  it('la promesa de un pedido durante la ejecución espera también a la repetición', async () => {
    const order: string[] = [];
    const gate = deferred();
    let calls = 0;

    const run = createSerialRunner(async () => {
      calls += 1;
      const n = calls;
      order.push(`start-${n}`);
      if (n === 1) await gate.promise;
      order.push(`end-${n}`);
    });

    const first = run();
    const second = run().then(() => order.push('second-resolved'));

    gate.resolve();
    await Promise.all([first, second]);

    expect(order).toEqual(['start-1', 'end-1', 'start-2', 'end-2', 'second-resolved']);
  });

  it('permite una ejecución nueva después de terminar', async () => {
    let calls = 0;
    const run = createSerialRunner(async () => {
      calls += 1;
    });
    await run();
    await run();
    expect(calls).toBe(2);
  });

  it('libera el runner aunque la tarea falle', async () => {
    let calls = 0;
    const run = createSerialRunner(async () => {
      calls += 1;
      if (calls === 1) throw new Error('falla');
    });
    await expect(run()).rejects.toThrow();
    await run();
    expect(calls).toBe(2);
  });
});
