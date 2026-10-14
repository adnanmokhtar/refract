import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class TrackingProjector {
  constructor(private readonly em: EntityManager) {}

  async apply(fields: string[]): Promise<void> {
    const f = Object.fromEntries(Array.from({ length: fields.length / 2 }, (_, i) => [fields[2 * i], fields[2 * i + 1]]));
    await this.em.fork().getConnection().execute(
      'INSERT INTO tracking_latest (tracking_no, status, at) VALUES (?, ?, ?) ON CONFLICT (tracking_no) DO UPDATE SET status = EXCLUDED.status, at = EXCLUDED.at WHERE tracking_latest.at < EXCLUDED.at',
      [f.trackingNo, f.status, f.at],
    );
  }
}
