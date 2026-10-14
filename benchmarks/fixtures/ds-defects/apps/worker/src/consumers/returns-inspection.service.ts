import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class ReturnsInspection {
  constructor(private readonly em: EntityManager) {}

  async inspect(evt: { returnId: string; photos: string[] }): Promise<void> {
    if (!evt.returnId) throw new Error('return id missing');
    await this.em.fork().getConnection().execute('UPDATE return_requests SET status = ? WHERE id = ?', ['received', evt.returnId]);
  }
}
