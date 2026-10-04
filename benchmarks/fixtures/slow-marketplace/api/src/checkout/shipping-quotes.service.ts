import { Injectable } from '@nestjs/common';
import pLimit from 'p-limit';
import { CarrierClient, Quote, QuoteItem } from '../shipping/carrier.client';

export interface QuoteCartDto {
  country: string;
  postcode: string;
  items: QuoteItem[];
}

export interface CartQuote {
  totalCents: number;
  currency: string;
  slowestEtaDays: number;
  lines: Quote[];
}

@Injectable()
export class ShippingQuotesService {
  constructor(private readonly carrier: CarrierClient) {}

  // POST /checkout/quotes — the shipping step of checkout. The aggregator prices one parcel
  // per call. Wholesale buyers send carts of several hundred lines.
  async quoteCart(cart: QuoteCartDto): Promise<CartQuote> {
    const destination = { country: cart.country, postcode: cart.postcode };
    const lines = await Promise.all(cart.items.map((item) => this.carrier.quote(item, destination)));
    return {
      totalCents: lines.reduce((sum, q) => sum + q.amountCents, 0),
      currency: lines[0]?.currency ?? 'EUR',
      slowestEtaDays: Math.max(0, ...lines.map((q) => q.etaDays)),
      lines,
    };
  }

  // GET /checkout/pickup-windows?day= — click-and-collect windows across a store's
  // warehouses (a store can have dozens).
  async pickupWindows(warehouseIds: string[], day: string) {
    const limit = pLimit(8);
    const windows = await Promise.all(
      warehouseIds.map((id) => limit(() => this.carrier.pickupWindow(id, day))),
    );
    return warehouseIds
      .map((id, i) => ({ warehouseId: id, window: windows[i] }))
      .filter((w) => w.window !== null);
  }
}
