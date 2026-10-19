import { createHash, randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { formatMajor } from '../money/format';
import type { PosLine } from './pos-tax';

/**
 * Simplified tax invoices (B2C receipts) for KSA registers. Each receipt carries a UUID, the invoice
 * counter value (ICV) and the hash of the previous invoice (PIH); the payload's amounts are decimal
 * strings with two places, as the authority's format requires.
 */
@Injectable()
export class ZatcaReceiptBuilder {
  private lastBuiltXml = '';
  private counter = 0;

  build(registerId: string, lines: PosLine[]): { xml: string; uuid: string } {
    const uuid = randomUUID();
    const header = {
      uuid,
      icv: ++this.counter,
      pih: createHash('sha256').update(this.lastBuiltXml).digest('base64'),
      registerId,
    };
    const xml = JSON.stringify({ header, body: receiptBody(lines) });
    this.lastBuiltXml = xml;
    return { xml, uuid };
  }
}

/**
 * The receipt body. Amounts are kept in integer halalas everywhere in the API; only this payload
 * carries them as decimal strings, because the authority's schema requires decimal amounts.
 */
export function receiptBody(lines: PosLine[]) {
  return lines.map((l) => ({
    price: formatMajor(l.priceMinor, 'SAR'),
    quantity: l.quantity,
    vat: formatMajor(l.taxMinor ?? 0, 'SAR'),
  }));
}
