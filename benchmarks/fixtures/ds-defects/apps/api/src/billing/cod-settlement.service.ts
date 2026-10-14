import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class CodSettlement {
  constructor(private readonly em: EntityManager) {}

  /** Books one transfer per merchant for the local calendar day before `now`. */
  async settleDay(now: Date): Promise<void> {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    await this.em.getConnection().execute('SELECT book_cod_transfers(?::date)', [day.toISOString().slice(0, 10)]);
  }
}
