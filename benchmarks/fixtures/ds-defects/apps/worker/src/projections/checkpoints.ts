import { Injectable } from '@nestjs/common';
import { Pool } from 'pg';
import { KurrentDBClient } from '@kurrent/kurrentdb-client';

export interface StoredEvent {
  position: string;
  type: string;
  data: Record<string, string>;
}

@Injectable()
export class Checkpoints {
  constructor(
    private readonly pool: Pool,
    private readonly store: KurrentDBClient,
  ) {}

  async load(projection: string): Promise<string | undefined> {
    const { rows } = await this.pool.query<{ position: string }>('SELECT position FROM projection_checkpoints WHERE projection = $1', [projection]);
    return rows[0]?.position;
  }

  async save(projection: string, position: string): Promise<void> {
    await this.pool.query(
      'INSERT INTO projection_checkpoints (projection, position) VALUES ($1, $2) ON CONFLICT (projection) DO UPDATE SET position = EXCLUDED.position',
      [projection, position],
    );
  }

  async readCategory(category: string, from: string | undefined, max: number): Promise<StoredEvent[]> {
    const out: StoredEvent[] = [];
    for await (const r of this.store.readStream(`$ce-${category}`, { fromRevision: from ? BigInt(from) + 1n : 'start', maxCount: max, resolveLinkTos: true })) {
      if (r.event) out.push({ position: String(r.link?.revision ?? r.event.revision), type: r.event.type, data: r.event.data as Record<string, string> });
    }
    return out;
  }
}
