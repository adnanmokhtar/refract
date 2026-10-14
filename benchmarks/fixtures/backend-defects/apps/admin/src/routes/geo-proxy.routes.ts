import { Router } from 'express';
import { env } from '../env.js';

export const geoProxyRouter = Router();
const router = geoProxyRouter;

/**
 * Documented pass-through proxy (ai/api-conventions.md does not apply to /admin/geo/*: the console
 * map widget talks to the geo provider's API through this hop, status and body unchanged).
 */
router.get('/geo/*splat', async (req, res) => {
  const upstreamPath = (req.params as { splat: string[] }).splat.join('/');
  const response = await fetch(`${env.GEO_BASE_URL}/${upstreamPath}`, { signal: AbortSignal.timeout(4000) });
  res.status(response.status).type(response.headers.get('content-type') ?? 'application/json').send(await response.text());
});
