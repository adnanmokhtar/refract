import { Injectable } from '@nestjs/common';
import { request } from 'undici';

export interface CallOptions {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  url: string;
  body?: unknown;
  requestTimeout?: number;
  retry?: { attempts: number; backoffMs?: number };
  signal?: AbortSignal;
}

/** The worker's outbound kernel: per-attempt timeout, retry on network errors, 408, 429 and 5xx. */
@Injectable()
export class HttpClient {
  async call<T>(opts: CallOptions): Promise<T> {
    const attempts = opts.retry?.attempts ?? 1;
    let last: unknown;
    for (let i = 0; i < attempts; i++) {
      try {
        const signals = [AbortSignal.timeout(opts.requestTimeout ?? 10_000), ...(opts.signal ? [opts.signal] : [])];
        const res = await request(opts.url, {
          method: opts.method,
          body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
          headers: { 'content-type': 'application/json' },
          signal: AbortSignal.any(signals),
        });
        if (res.statusCode < 400) return (await res.body.json()) as T;
        if (![408, 429, 500, 502, 503, 504].includes(res.statusCode)) throw new Error(`HTTP ${res.statusCode}`);
        last = new Error(`HTTP ${res.statusCode}`);
      } catch (err) {
        if (opts.signal?.aborted) throw err;
        last = err;
      }
      if (i + 1 < attempts) await new Promise((r) => setTimeout(r, Math.random() * (opts.retry?.backoffMs ?? 500) * 2 ** i));
    }
    throw last;
  }
}
