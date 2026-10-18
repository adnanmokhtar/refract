import { tolerance } from './harness';

interface Captured {
  status: number;
  body: unknown;
}

const V1_BASE = process.env.V1_BASE_URL ?? 'http://127.0.0.1:8000';
const V2_BASE = process.env.V2_BASE_URL ?? 'http://127.0.0.1:3000';

// One Sanctum personal access token, valid on both halves (V2 reads V1's personal_access_tokens).

function strip(body: unknown): unknown {
  const text = JSON.stringify(body);
  return JSON.parse(text, (key, value) => (tolerance.ignore.some((p) => p.endsWith(`.${key}`)) ? undefined : value));
}

export async function replay(req: { method: string; path: string; body?: unknown }): Promise<[Captured, Captured]> {
  const send = async (base: string): Promise<Captured> => {
    const res = await fetch(`${base}${req.path}`, { method: req.method, headers: { 'content-type': 'application/json', accept: 'application/json', authorization: `Bearer ${process.env.PARITY_TOKEN ?? ''}` }, body: req.body ? JSON.stringify(req.body) : undefined });
    return { status: res.status, body: strip(await res.json().catch(() => null)) };
  };
  return [await send(V1_BASE), await send(V2_BASE)];
}
