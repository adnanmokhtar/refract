import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** End-of-day takings per register. POS is SAR-only (one market, ai/business-domain.md § Tax policy). */
@Injectable()
export class PosTakingsQuery {
  constructor(private readonly em: EntityManager) {}

  takings(registerId: string, day: string) {
    return this.em.getConnection().execute(
      `select coalesce(sum(r.total_minor), 0) as takings_minor, count(*) as receipts
         from pos_receipts r
        where r.register_id = ?
          and (r.issued_at at time zone 'Asia/Riyadh')::date = ?`,
      [registerId, day],
    );
  }
}
