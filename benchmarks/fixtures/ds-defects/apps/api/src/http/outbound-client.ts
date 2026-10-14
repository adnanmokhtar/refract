import { Injectable } from '@nestjs/common';
import { request as undiciRequest } from 'undici';

export interface OutboundRequest {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  url: string;
  headers?: Record<string, string>;
  body?: unknown;
  timeoutMs?: number;
  retry?: { attempts: number };
  signal?: AbortSignal;
}

const BASE_MS = 200;
const CAP_MS = 5_000;

/** Full jitter: a random delay in [0, min(cap, base · 2^attempt)), so callers that fail together retry apart. */
export const backoffMs = (attempt: number): number => Math.random() * Math.min(CAP_MS, BASE_MS * 2 ** attempt);

const RETRYABLE = new Set([408, 429, 500, 502, 503, 504]);

/** The shared client every outbound integration in apps/api uses (carriers, tax, maps). */
@Injectable()
export class OutboundClient {
  async request<T>(req: OutboundRequest): Promise<T> {
    const attempts = req.retry?.attempts ?? 1;
    let lastError: unknown;
    for (let attempt = 0; attempt < attempts; attempt++) {
      try {
        const res = await undiciRequest(req.url, {
          method: req.method,
          headers: { 'content-type': 'application/json', ...req.headers },
          body: req.body === undefined ? undefined : JSON.stringify(req.body),
          signal: AbortSignal.any([AbortSignal.timeout(req.timeoutMs ?? 10_000), ...(req.signal ? [req.signal] : [])]),
        });
        if (res.statusCode < 400) return (await res.body.json()) as T;
        if (!RETRYABLE.has(res.statusCode)) throw new Error(`HTTP ${res.statusCode} from ${req.url}`);
        lastError = new Error(`HTTP ${res.statusCode}`);
      } catch (err) {
        if (req.signal?.aborted) throw err;
        lastError = err;
      }
      if (attempt + 1 < attempts) await new Promise((r) => setTimeout(r, backoffMs(attempt)));
    }
    throw lastError;
  }
}
