import { EntityManager } from '@mikro-orm/postgresql';
import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { CreditLedgerEntry, CreditWallet } from './entities';

/** AI credits a workspace buys in packs; one ledger row per debit source (unique source_key). */
@Injectable()
export class CreditWalletService {
  constructor(private readonly em: EntityManager) {}

  async balance(accountId: string): Promise<number> {
    const wallet = await this.em.findOne(CreditWallet, { accountId });
    return wallet?.balance ?? 0;
  }

  async debit(accountId: string, credits: number, sourceKey: string): Promise<void> {
    const wallet = await this.em.findOneOrFail(CreditWallet, { accountId });
    if (wallet.balance < credits) {
      throw new HttpException('Not enough AI credits', HttpStatus.PAYMENT_REQUIRED);
    }
    wallet.balance = wallet.balance - credits;
    this.em.create(CreditLedgerEntry, { accountId, delta: -credits, sourceKey, createdAt: new Date() });
    await this.em.flush();
  }
}
