import type { Request } from 'express';

const ORDERS_API = process.env.ORDERS_API_URL ?? 'http://orders.internal:8080';

/** Calls the orders API on behalf of the MCP caller. */
export async function ordersApi(req: Request, path: string): Promise<unknown> {
  const res = await fetch(`${ORDERS_API}${path}`, {
    headers: { accept: 'application/json', authorization: req.headers.authorization ?? '' },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`orders API answered ${res.status}`);
  return res.json();
}
