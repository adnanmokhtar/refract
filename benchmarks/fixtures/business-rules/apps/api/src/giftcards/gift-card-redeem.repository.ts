import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class GiftCardRedeemRepository {
  constructor(private readonly em: EntityManager) {}

  /** Spends part of a gift card at checkout. */
  async spend(code: string, amountMinor: number): Promise<void> {
    await this.em.getConnection().execute(
      'update gift_cards set balance_minor = balance_minor - ? where code = ?',
      [amountMinor, code],
    );
  }
}
