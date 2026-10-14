import { Injectable } from '@nestjs/common';

export class UpstreamError extends Error {
  constructor(readonly provider: string, readonly upstreamStatus: number) {
    super(`${provider} answered ${upstreamStatus}`);
  }
}

/**
 * Outbound HTTP for every provider call in apps/api. Redirects are never followed: a 30x on a
 * POST would be replayed as a GET by fetch and look like success.
 */
@Injectable()
export class OutboundHttp {
  async postJson<T>(provider: string, url: string, body: unknown, timeoutMs = 5000): Promise<T> {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      redirect: 'manual',
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) throw new UpstreamError(provider, res.status);
    return (await res.json()) as T;
  }
}
