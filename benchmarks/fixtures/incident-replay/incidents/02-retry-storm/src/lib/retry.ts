// Generic retry helper. backoffMs is the base delay; 0 means retry immediately.
export async function fetchWithRetry<T>(call: () => Promise<T>, opts: { retries: number; backoffMs: number }): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= opts.retries; attempt++) {
    try {
      return await call();
    } catch (err) {
      lastErr = err;
      if (opts.backoffMs > 0) await new Promise((r) => setTimeout(r, opts.backoffMs * 2 ** attempt));
    }
  }
  throw lastErr;
}
