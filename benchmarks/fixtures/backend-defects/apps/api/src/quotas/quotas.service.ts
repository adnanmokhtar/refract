import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';

@Injectable()
export class QuotasService {
  constructor(private readonly em: EntityManager) {}

  /** Monthly API-call quota per merchant plan. */
  async consume(merchantId: string): Promise<void> {
    const [row] = await this.em.getConnection().execute('select used, quota from api_quotas where merchant_id = ?', [merchantId]);
    if (row && row.used >= row.quota) {
      throw { message: 'Monthly API quota exceeded', code: 'QUOTA_EXCEEDED', retryAfterDays: 1 };
    }
    await this.em.getConnection().execute('update api_quotas set used = used + 1 where merchant_id = ?', [merchantId]);
  }
}
