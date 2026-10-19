import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';

const toVector = (v: number[]) => `[${v.join(',')}]`;

/** "Similar solved tickets" panel in the agent inbox. */
@Injectable()
export class SimilarTicketsRepository {
  constructor(private readonly em: EntityManager) {}

  async similar(tenantId: string, embedding: number[], k = 5): Promise<{ ticket_id: string; distance: number }[]> {
    return this.em.getConnection().execute(
      'SELECT ticket_id, embedding <=> ?::vector AS distance FROM ticket_embeddings WHERE tenant_id = ? ORDER BY embedding <=> ?::vector LIMIT ?',
      [toVector(embedding), tenantId, toVector(embedding), k],
    );
  }
}
