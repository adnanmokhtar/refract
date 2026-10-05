import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

export interface Wallet {
  id: string;
  ownerId: string;
}

// Account credit lives in wallets. transfer() always moves money FROM the first wallet TO the second.
@Injectable()
export class CreditTransferService {
  constructor(private readonly db: PrismaClient) {}

  async transfer(from: Wallet, to: Wallet, amountCents: number, reason: string): Promise<void> {
    if (amountCents <= 0) throw new Error('transfer amount must be positive');
    await this.db.$transaction([
      this.db.$executeRaw`update wallet set balance_cents = balance_cents - ${amountCents} where id = ${from.id} and balance_cents >= ${amountCents}`,
      this.db.$executeRaw`update wallet set balance_cents = balance_cents + ${amountCents} where id = ${to.id}`,
      this.db.$executeRaw`insert into wallet_transfer (from_wallet, to_wallet, amount_cents, reason) values (${from.id}, ${to.id}, ${amountCents}, ${reason})`,
    ]);
  }

  // A customer pays part of an invoice with account credit: customer wallet → merchant wallet.
  async payWithCredit(customerWallet: Wallet, merchantWallet: Wallet, amountCents: number): Promise<void> {
    await this.transfer(customerWallet, merchantWallet, amountCents, 'invoice-payment');
  }

  async topUp(customerWallet: Wallet, promoWallet: Wallet, amountCents: number): Promise<void> {
    await this.transfer(promoWallet, customerWallet, amountCents, 'promo-top-up');
  }

  async expireUnusedCredit(customerWallet: Wallet, promoWallet: Wallet, amountCents: number): Promise<void> {
    await this.transfer(customerWallet, promoWallet, amountCents, 'promo-expiry');
  }

  // A refund of an invoice paid with credit gives the credit back: merchant wallet → customer wallet.
  async refundCredit(customerWallet: Wallet, merchantWallet: Wallet, amountCents: number): Promise<void> {
    await this.transfer(customerWallet, merchantWallet, amountCents, 'invoice-refund');
  }
}
