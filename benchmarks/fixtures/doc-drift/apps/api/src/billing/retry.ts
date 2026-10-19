/**
 * Delivery retry policy for outbound webhooks and other idempotent calls.
 */

export function backoffMs(attempt: number, baseMs = 500): number {
  const exp = Math.min(attempt, 10);
  const jitter = Math.floor(Math.random() * baseMs);
  return baseMs * 2 ** exp + jitter;
}

export const MAX_BACKOFF_MS = 5 * 60 * 1000;
export const PARK_AFTER_MS = 24 * 60 * 60 * 1000;
export const DEFAULT_BASE_MS = 500;

export interface RetryOptions {
  /** Attempts before the call is given up (the RETRY_LIMIT setting). */
  limit: number;
  /** Base delay for the first retry. */
  baseMs?: number;
  /** Called before each sleep; used by the worker to log progress. */
  onRetry?: (attempt: number, delayMs: number, error: unknown) => void;
}

export class RetriesExhaustedError extends Error {
  constructor(
    readonly attempts: number,
    readonly lastError: unknown,
  ) {
    super(`gave up after ${attempts} attempts`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function withRetries<T>(call: () => Promise<T>, options: RetryOptions): Promise<T> {
  const { limit, baseMs = DEFAULT_BASE_MS, onRetry } = options;
  let lastError: unknown;

  // The delivery loop: one call per attempt, exponential backoff with jitter in between.
  for (let attempt = 0; attempt < limit; attempt += 1) {
    try {
      return await call();
    } catch (error) {
      lastError = error;
      const delay = Math.min(backoffMs(attempt, baseMs), MAX_BACKOFF_MS);
      onRetry?.(attempt + 1, delay, error);
      await sleep(delay);
    }
  }
  throw new RetriesExhaustedError(limit, lastError);
}
