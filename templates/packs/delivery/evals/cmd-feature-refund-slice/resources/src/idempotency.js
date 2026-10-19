// Idempotency-Key handling. Wrap every write route: a repeat of the same key returns the first
// response unchanged and runs nothing a second time.

export function withIdempotency(handler) {
  return async function idempotent(ctx) {
    const key = ctx.headers['idempotency-key'];
    if (!key) {
      return { status: 400, headers: {}, body: { error: 'Idempotency-Key header is required' } };
    }
    const scope = `${ctx.tenantId} ${ctx.route} ${key}`;
    if (ctx.store.idempotency.has(scope)) return ctx.store.idempotency.get(scope);
    const response = await handler(ctx);
    ctx.store.idempotency.set(scope, response);
    return response;
  };
}
