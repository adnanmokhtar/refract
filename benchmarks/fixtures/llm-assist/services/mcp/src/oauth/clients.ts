import { db } from '../db.js';

export interface OAuthClient {
  id: string;
  name: string;
  redirectUris: string[];
}

export async function findClient(id: string | undefined): Promise<OAuthClient | null> {
  if (!id) return null;
  const { rows } = await db.query('SELECT id, name, redirect_uris FROM oauth_clients WHERE id = $1', [id]);
  return rows[0] ? { id: rows[0].id, name: rows[0].name, redirectUris: rows[0].redirect_uris } : null;
}
