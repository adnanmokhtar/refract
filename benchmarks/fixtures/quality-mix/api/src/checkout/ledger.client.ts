import { Injectable } from '@nestjs/common';

// The general ledger service. Every posted line is a write the finance close depends on.
@Injectable()
export class LedgerClient {
  async post(reference: string, accountCode: string, amountCents: number): Promise<void> {
    const res = await fetch(`${process.env.LEDGER_URL}/entries`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ reference, account: accountCode, amount: amountCents }),
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`ledger post ${reference}: ${res.status}`);
  }
}
