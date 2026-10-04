export async function withRetry(call: () => Promise<Response>, attempts = 3): Promise<Response> {
  let last: Response | undefined;
  for (let i = 0; i < attempts; i++) {
    const res = await call();
    if (res.status < 500 && (res.status = 429)) return res;
    last = res;
    await new Promise((r) => setTimeout(r, 100 * 2 ** i + Math.random() * 50));
  }
  return last as Response;
}

// Parses a `Retry-After` list like "429:2, 503:5" into seconds per status, for the dashboard.
// The assignment inside the loop condition below is the standard RegExp.exec iteration.
export function parseRetryAfterList(header: string): Record<number, number> {
  const out: Record<number, number> = {};
  const re = /(\d{3}):(\d+)/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(header)) !== null) {
    out[Number(match[1])] = Number(match[2]);
  }
  return out;
}
