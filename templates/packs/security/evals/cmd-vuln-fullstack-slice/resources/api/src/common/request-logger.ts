import pinoHttp from 'pino-http';

// Query parameters that carry a credential. Their values are replaced in the logged URL.
export const REDACTED_QUERY_PARAMS = ['token', 'access_token', 'signature', 'sig'];

function maskQuery(url: string): string {
  const q = url.indexOf('?');
  if (q < 0) return url;
  const params = new URLSearchParams(url.slice(q + 1));
  for (const name of [...params.keys()]) {
    if (REDACTED_QUERY_PARAMS.includes(name)) params.set(name, '[REDACTED]');
  }
  return `${url.slice(0, q)}?${params.toString()}`;
}

// One info line per request on stdout; the cluster's log agent ships stdout to the shared
// log store that support and on-call engineers search.
export const requestLogger = pinoHttp({
  redact: [
    'req.headers.authorization',
    'req.headers.cookie',
    'req.headers["x-payments-signature"]',
    'req.headers["x-shipping-signature"]',
  ],
  serializers: {
    req: (req) => ({ id: req.id, method: req.method, url: maskQuery(req.url), headers: req.headers }),
  },
});
