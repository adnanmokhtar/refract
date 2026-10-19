import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class CheckpointStore {
  constructor(private readonly em: EntityManager) {}

  async get(name: string): Promise<Date> {
    const [row] = await this.em.getConnection().execute<{ at: Date }[]>('SELECT at FROM sync_checkpoints WHERE name = ?', [name]);
    return row ? row.at : new Date(0);
  }

  async set(name: string, at: Date): Promise<void> {
    await this.em
      .getConnection()
      .execute('INSERT INTO sync_checkpoints (name, at) VALUES (?, ?) ON CONFLICT (name) DO UPDATE SET at = EXCLUDED.at', [name, at]);
  }
}
