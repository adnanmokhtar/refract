export class DeadlineExceeded extends Error {
  constructor(ms: number) {
    super(`job deadline of ${ms} ms exceeded`);
  }
}

/**
 * Bounds one attempt of a job. On expiry the AbortSignal handed to the work fires — every outbound client in
 * this worker takes it and cancels its request — and the attempt rejects.
 */
export async function withDeadline<R>(ms: number, work: (signal: AbortSignal) => Promise<R>): Promise<R> {
  const controller = new AbortController();
  let timer: NodeJS.Timeout | undefined;
  const expired = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      controller.abort(new DeadlineExceeded(ms));
      reject(new DeadlineExceeded(ms));
    }, ms);
  });
  try {
    return await Promise.race([work(controller.signal), expired]);
  } finally {
    clearTimeout(timer);
  }
}
