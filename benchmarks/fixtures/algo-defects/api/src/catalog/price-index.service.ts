import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Product } from './product.entity';

/** SKU → price map the POS sync and the partner feed read; rebuilt whenever a price changes. */
@Injectable()
export class PriceIndexService {
  constructor(private readonly em: EntityManager) {}

  async priceBySku(storeId: string): Promise<Record<string, number>> {
    const products = await this.em.find(
      Product,
      { store: storeId, archivedAt: null },
      { fields: ['sku', 'priceMinor'] },
    );
    return products.reduce((acc, p) => ({ ...acc, [p.sku]: p.priceMinor }), {} as Record<string, number>);
  }

  async skusAbove(storeId: string, minPriceMinor: number): Promise<string[]> {
    const index = await this.priceBySku(storeId);
    return Object.entries(index)
      .filter(([, price]) => price >= minPriceMinor)
      .map(([sku]) => sku);
  }
}
