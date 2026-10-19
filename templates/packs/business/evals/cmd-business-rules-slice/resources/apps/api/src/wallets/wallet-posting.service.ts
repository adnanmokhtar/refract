import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { MerchantWallet } from './merchant-wallet.entity';
import { WalletTransaction } from './wallet-transaction.entity';
import { assertNotOverdrawn } from '../accounting/clearing-accounts';

export interface WalletSource {
  sourceType: string;
  sourceId: string;
}

@Injectable()
export class WalletPostingService {
  constructor(private readonly em: EntityManager) {}

  /** The movement and the cache change commit together; the nightly sweep compares the two. */
  async post(walletId: string, amountMinor: number, source: WalletSource): Promise<void> {
    await this.em.transactional(async (tx) => {
      const wallet = await tx.findOneOrFail(MerchantWallet, walletId, { lockMode: 4 });
      tx.create(WalletTransaction, { walletId, amountMinor, currency: wallet.currency, kind: 'payment', ...source } as any);
      wallet.balanceMinor += amountMinor;
      assertNotOverdrawn('merchant_wallet', wallet.balanceMinor);
    });
  }
}
