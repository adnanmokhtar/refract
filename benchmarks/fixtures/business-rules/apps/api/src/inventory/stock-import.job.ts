import { Injectable } from '@nestjs/common';
import { EntityManager, raw } from '@mikro-orm/postgresql';
import { ProductVariant } from './product-variant.entity';

/** Applies the marketplace channel's nightly sales file: units sold elsewhere leave our shelf too. */
@Injectable()
export class StockImportJob {
  constructor(private readonly em: EntityManager) {}

  async applySoldElsewhere(rows: { sku: string; sold: number }[]): Promise<void> {
    for (const row of rows) {
      await this.em.nativeUpdate(ProductVariant, { sku: row.sku }, { stockOnHand: raw('stock_on_hand - ?', [row.sold]) });
    }
  }
}
