import http from 'node:http';
import { handle, streamOrderEvents, renderExport } from './app.mjs';

// Server-rendered storefront behind caddy-edge (edge/caddy/shop.caddy).
const server = http.createServer(async (req, res) => {
  if (req.url.startsWith('/events/')) {
    res.writeHead(200, { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' });
    return streamOrderEvents(req, res);
  }
  if (req.url.startsWith('/exports/')) {
    // Order-history exports for large accounts take up to 90 s to render.
    return renderExport(req, res, { timeoutMs: 90_000 });
  }
  return handle(req, res);
});

server.keepAliveTimeout = 5_000;
server.headersTimeout = 6_000;

server.listen(Number(process.env.PORT ?? 3000));
