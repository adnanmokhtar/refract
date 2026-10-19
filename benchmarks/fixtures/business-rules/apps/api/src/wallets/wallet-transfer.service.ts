import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { FxService } from '../fx/fx.service';
import { MerchantWallet } from './merchant-wallet.entity';
import { WalletTransaction } from './wallet-transaction.entity';

/** Moves money between two wallets of the same merchant (e.g. the USD wallet to the EGP wallet). */
@Injectable()
export class WalletTransferService {
  constructor(private readonly em: EntityManager, private readonly fx: FxService) {}

  async transfer(fromId: string, toId: string, amountMinor: number, transferId: string): Promise<void> {
    await this.em.transactional(async (tx) => {
      const from = await tx.findOneOrFail(MerchantWallet, fromId);
      const to = await tx.findOneOrFail(MerchantWallet, toId);
      const fromCurrency = from.currency;
      const toCurrency = to.currency;
      const convertedMinor = await this.fx.convertAmount(amountMinor, fromCurrency, toCurrency);
      const legs = [
        { walletId: from.id, amountMinor: -amountMinor, currency: fromCurrency, leg: 0 },
        { walletId: to.id, amountMinor: convertedMinor, currency: toCurrency, leg: 1 },
      ];
      for (const l of legs) tx.create(WalletTransaction, { ...l, kind: 'transfer', sourceType: 'transfer', sourceId: transferId } as any);
      from.balanceMinor -= amountMinor;
      to.balanceMinor += convertedMinor;
    });
  }
}
