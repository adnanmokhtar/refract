// Retries a request the API answered 429 / 503, honouring its Retry-After header.
// RFC 9110: Retry-After is a delay in SECONDS (or an HTTP date).
export async function withRetry(call: () => Promise<Response>, attempts = 3): Promise<Response> {
  for (let attempt = 1; ; attempt++) {
    const res = await call();
    if ((res.status !== 429 && res.status !== 503) || attempt >= attempts) return res;
    const retryAfter = Number(res.headers.get('retry-after') ?? '1');
    await new Promise((resolve) => setTimeout(resolve, retryAfter));
  }
}
