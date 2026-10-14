import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { MerchantAccount } from './merchant-account.entity';

/**
 * Merchants buy label-OCR credits (scanning handwritten return labels with the vision model). One page costs
 * one credit; the debit happens after the model answered.
 */
@Injectable()
export class OcrCredits {
  constructor(private readonly em: EntityManager) {}

  async debit(merchantId: string, pages: number): Promise<void> {
    const account = await this.em.findOneOrFail(MerchantAccount, { merchantId });
    account.ocrCredits = Math.max(0, account.ocrCredits - pages);
    await this.em.flush();
  }
}
