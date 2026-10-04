export async function withRetry(call: () => Promise<Response>, attempts = 3): Promise<Response> {
  let last: Response | undefined;
  for (let i = 0; i < attempts; i++) {
    const res = await call();
    if (res.status < 500 && res.status !== 429) return res;
    last = res;
    await new Promise((r) => setTimeout(r, 100 * 2 ** i + Math.random() * 50));
  }
  return last as Response;
}
