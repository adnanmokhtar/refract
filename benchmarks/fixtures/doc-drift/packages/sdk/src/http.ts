export interface HttpClient {
  get<T>(path: string, query?: Record<string, string | number | undefined>): Promise<T>;
  post<T>(path: string, body?: unknown): Promise<T>;
}

export function httpClient(baseUrl: string, apiKey: string, timeoutMs: number, retries: number): HttpClient {
  async function send<T>(method: string, path: string, body?: unknown): Promise<T> {
    let attempt = 0;
    for (;;) {
      const res = await fetch(baseUrl + path, {
        method,
        headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (res.ok) return (await res.json()) as T;
      if (method !== 'GET' || attempt >= retries || res.status < 500) {
        throw new Error(`${method} ${path} failed with ${res.status}`);
      }
      attempt += 1;
    }
  }
  return {
    get: (path, query) => {
      const qs = new URLSearchParams();
      for (const [k, v] of Object.entries(query ?? {})) if (v !== undefined) qs.set(k, String(v));
      return send('GET', qs.size ? `${path}?${qs}` : path);
    },
    post: (path, body) => send('POST', path, body),
  };
}
