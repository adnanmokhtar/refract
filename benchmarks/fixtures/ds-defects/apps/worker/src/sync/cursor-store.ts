import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';

@Injectable()
export class CursorStore {
  constructor(private readonly pool: Pool) {}

  async get(name: string): Promise<string | undefined> {
    const { rows } = await this.pool.query<{ position: string }>('SELECT position FROM sync_cursors WHERE name = $1', [name]);
    return rows[0]?.position;
  }

  async set(name: string, position: string): Promise<void> {
    await this.pool.query('INSERT INTO sync_cursors (name, position) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET position = EXCLUDED.position', [name, position]);
  }
}
