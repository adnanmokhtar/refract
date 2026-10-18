// Runs during prerender to inline the first page of orders into the HTML. Node, not the browser:
// there is no session token here and the request goes to the internal origin.
export async function prefetchOrders(origin: string): Promise<unknown> {
  const res = await fetch(`${origin}/api/v2/orders?limit=20`, { headers: { accept: 'application/json' } });
  if (!res.ok) throw new Error(`prefetch failed: ${res.status}`);
  return res.json();
}
