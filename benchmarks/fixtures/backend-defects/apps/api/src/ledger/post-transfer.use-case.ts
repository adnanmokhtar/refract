import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { InsufficientFundsError, AccountFrozenError } from './ledger.errors';

@Injectable()
export class PostTransferUseCase {
  constructor(private readonly em: EntityManager) {}

  /** Called from POST /v1/transfers with the client's source account. */
  async execute(fromAccount: string, toAccount: string, amount: string): Promise<void> {
    const [acc] = await this.em.getConnection().execute('select balance, frozen from accounts where id = ?', [fromAccount]);
    if (acc?.frozen) throw new AccountFrozenError('account is frozen', fromAccount);
    if (Number(acc?.balance ?? 0) < Number(amount)) throw new InsufficientFundsError('insufficient funds', fromAccount);
    await this.em.getConnection().execute('select post_transfer(?, ?, ?)', [fromAccount, toAccount, amount]);
  }
}
