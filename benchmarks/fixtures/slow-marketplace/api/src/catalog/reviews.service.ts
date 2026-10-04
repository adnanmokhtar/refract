import { Injectable } from '@nestjs/common';
import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { Review } from './review.entity';

// GET /products/:productId/reviews?before=<iso> — the review list under the product page,
// newest first, 10 at a time.
@Injectable()
export class ReviewsService {
  constructor(private readonly em: EntityManager) {}

  async forProduct(productId: string, before?: Date) {
    return this.em.find(
      Review,
      before ? { product: productId, createdAt: { $lt: before } } : { product: productId },
      { fields: ['id', 'rating', 'body', 'photoUrl', 'createdAt'], orderBy: { createdAt: QueryOrder.DESC }, limit: 10 },
    );
  }
}
