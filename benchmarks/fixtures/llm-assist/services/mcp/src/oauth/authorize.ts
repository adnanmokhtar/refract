import type { Request, Response } from 'express';
import { findClient } from './clients.js';

/** Authorization endpoint of the MCP server's own authorization server (same app, opaque tokens). */
export async function authorize(req: Request, res: Response): Promise<void> {
  const q = req.query as Record<string, string>;
  const client = await findClient(q.client_id);
  if (!client) {
    res.status(400).json({ error: 'invalid_client' });
    return;
  }
  if (!client.redirectUris.includes(q.redirect_uri)) {
    res.status(400).json({ error: 'invalid_request', error_description: 'redirect_uri must match a registered URI exactly' });
    return;
  }
  if (!q.code_challenge || q.code_challenge_method !== 'S256') {
    res.status(400).json({ error: 'invalid_request', error_description: 'PKCE with S256 is required' });
    return;
  }
  res.render('consent', { client: client.name, scope: q.scope, state: q.state, challenge: q.code_challenge });
}
