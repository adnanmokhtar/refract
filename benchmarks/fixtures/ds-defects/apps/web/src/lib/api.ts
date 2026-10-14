export const api = {
  async get<T>(path: string): Promise<T> {
    const res = await fetch(`/api${path}`, { credentials: 'include' });
    if (!res.ok) throw new Response(res.statusText, { status: res.status });
    return (await res.json()) as T;
  },
  async post<T>(path: string, body: unknown): Promise<T> {
    const res = await fetch(`/api${path}`, { method: 'POST', credentials: 'include', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
    if (!res.ok) throw new Response(res.statusText, { status: res.status });
    return (await res.json()) as T;
  },
};
