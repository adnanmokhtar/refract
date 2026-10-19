import { Injectable } from '@nestjs/common';
import { TaxRates } from '../tax/tax-rates.service';
import type { Order } from '../orders/order.entity';
import type { OrderLine } from '../orders/order-line.entity';

/** Tax on a web order, computed at checkout and stored on each line. */
@Injectable()
export class CheckoutTax {
  constructor(private readonly rates: TaxRates) {}

  async applyTo(order: Order, lines: OrderLine[]): Promise<void> {
    const store = order.store;
    const taxRate = await this.rates.forCountry(store.taxCountry, order.createdAt);
    let taxTotal = 0;
    for (const line of lines) {
      line.taxRateBp = Math.round(taxRate * 10_000);

      line.taxMinor = Math.round(line.quantity * line.unitPriceMinor * taxRate);
      taxTotal += line.taxMinor;
    }
    order.taxMinor = taxTotal;
  }
}
