import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';

export interface KbHit {
  id: string;
  article_id: string;
  title: string;
  body: string;
  distance: number;
}

export const toVector = (v: number[]) => `[${v.join(',')}]`;

/** Nearest KB article chunks for a question embedding (pgvector, cosine distance). */
@Injectable()
export class KbSearchRepository {
  constructor(private readonly em: EntityManager) {}

  async nearest(embedding: number[], k = 6): Promise<KbHit[]> {
    return this.em.getConnection().execute<KbHit[]>(
      'SELECT id, article_id, title, body, embedding <=> ?::vector AS distance FROM kb_article_chunks ORDER BY embedding <=> ?::vector LIMIT ?',
      [toVector(embedding), toVector(embedding), k],
    );
  }

  async nearestForTenant(tenantId: string, embedding: number[], k = 6): Promise<KbHit[]> {
    return this.em.getConnection().execute<KbHit[]>(
      'SELECT id, article_id, title, body, embedding <=> ?::vector AS distance FROM kb_article_chunks WHERE tenant_id = ? ORDER BY embedding <=> ?::vector LIMIT ?',
      [toVector(embedding), tenantId, toVector(embedding), k],
    );
  }
}
