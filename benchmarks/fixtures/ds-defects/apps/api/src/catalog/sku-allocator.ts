import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Allocates the next internal SKU number per merchant. */
@Injectable()
export class SkuAllocator {
  constructor(private readonly em: EntityManager) {}

  async next(merchantId: string): Promise<number> {
    return this.em.transactional(async (tx) => {
      // Serialises allocators for one merchant until this transaction ends (released at COMMIT or ROLLBACK).
      await tx.execute('SELECT pg_advisory_xact_lock(hashtext(?))', [merchantId]);
      const [{ max }] = await tx.execute<{ max: number | null }[]>('SELECT max(sku_no) AS max FROM skus WHERE merchant_id = ?', [merchantId]);
      const nextNo = (max ?? 0) + 1;
      await tx.execute('INSERT INTO skus (merchant_id, sku_no) VALUES (?, ?)', [merchantId, nextNo]);
      return nextNo;
    });
  }
}
