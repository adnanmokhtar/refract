import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ProductVariant } from './product-variant.entity';

/** Stock leaves the shelf when an order is placed. On-hand stock never goes below zero. */
@Injectable()
export class StockService {
  constructor(private readonly em: EntityManager) {}

  async take(variantId: string, quantity: number): Promise<void> {
    const variant = await this.em.findOneOrFail(ProductVariant, variantId, { lockMode: 4 });
    if (variant.stockOnHand < quantity) throw new ConflictException('out of stock');
    variant.stockOnHand -= quantity;
    await this.em.flush();
  }
}
