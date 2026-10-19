import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { WalletPostingService } from '../wallets/wallet-posting.service';

@Injectable()
export class PayoutService {
  constructor(private readonly em: EntityManager, private readonly postings: WalletPostingService) {}

  get(id: string) {
    return this.em.findOneOrFail('Payout', id);
  }

  async send(walletId: string, amountMinor: number) {
    return this.postings.post(walletId, -amountMinor, { sourceType: 'payout', sourceId: walletId });
  }
}
