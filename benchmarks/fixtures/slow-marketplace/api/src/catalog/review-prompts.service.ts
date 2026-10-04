import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

// Which of these products has the buyer not reviewed yet? One query, keyed by author.
@Injectable()
export class ReviewPromptsService {
  constructor(private readonly em: EntityManager) {}

  async pendingForProducts(buyerId: string, productIds: string[]): Promise<string[]> {
    if (productIds.length === 0) return [];
    const reviewed: { product_id: string }[] = await this.em.execute(
      'select product_id from review where author_id = ? and product_id = any(?)',
      [buyerId, productIds.slice(0, 100)],
    );
    const done = new Set(reviewed.map((r) => r.product_id));
    return productIds.filter((id) => !done.has(id));
  }
}
