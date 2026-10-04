export async function api<T = unknown>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, { credentials: 'include', ...init, headers: { 'content-type': 'application/json', ...init?.headers } });
  if (!res.ok) throw new Error(`${init?.method ?? 'GET'} ${path} failed with ${res.status}`);
  return (res.status === 204 ? undefined : await res.json()) as T;
}
