import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Customer wallet top-ups (a gift from a merchant, a goodwill credit from support). */
@Injectable()
export class WalletLedgerService {
  constructor(private readonly em: EntityManager) {}

  async topUp(walletId: string, amountMinor: number, currency: string, reason: string, email: string): Promise<void> {
    await this.em.getConnection().execute(
      `insert into wallet_transactions (id, wallet_id, amount_minor, currency, kind, source_type, source_id, customer_email)
       values (gen_random_uuid(), ?, ?, ?, 'topup', 'support', ?, ?)`,
      [walletId, amountMinor, currency, reason, email],
    );
  }
}
