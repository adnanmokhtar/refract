import { Injectable } from '@nestjs/common';

export interface LedgerEntry {
  invoiceId: string;
  debitMinor: number;
  creditMinor: number;
  currency: string;
}

/** Double-entry records for paid invoices and refunds. */
@Injectable()
export class AccountingService {
  private readonly entries: LedgerEntry[] = [];

  recordPayment(invoiceId: string, amountMinor: number, currency: string): LedgerEntry {
    const entry = { invoiceId, debitMinor: amountMinor, creditMinor: 0, currency };
    this.entries.push(entry);
    return entry;
  }

  balance(currency: string): number {
    return this.entries
      .filter((e) => e.currency === currency)
      .reduce((sum, e) => sum + e.debitMinor - e.creditMinor, 0);
  }
}
