import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface RateBand {
  minKg: number;
  maxKg: number;
  feeMinor: number;
}

export interface OrderWeight {
  orderId: string;
  weightKg: number;
}

export interface Quote {
  orderId: string;
  feeMinor: number | null;
}

/** Nightly re-quote of every open order against the store's current courier rate card. */
@Injectable()
export class RateCardService {
  constructor(private readonly em: EntityManager) {}

  async requoteOpenOrders(storeId: string, orders: OrderWeight[]): Promise<Quote[]> {
    const rates = await this.em
      .getConnection()
      .execute<RateBand[]>('SELECT min_kg AS "minKg", max_kg AS "maxKg", fee_minor AS "feeMinor" FROM rate_bands WHERE store_id = ?', [storeId]);
    const quotes: Quote[] = [];
    for (const order of orders) {
      const sorted = rates.slice().sort((a, b) => a.minKg - b.minKg);
      const band = sorted.find((r) => order.weightKg >= r.minKg && order.weightKg < r.maxKg);
      quotes.push({ orderId: order.orderId, feeMinor: band ? band.feeMinor : null });
    }
    return quotes;
  }
}
