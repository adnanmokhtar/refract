import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { EmbeddingsClient } from '../llm/embeddings.client';
import { KbArticle } from './kb-article.entity';
import { toVector } from './kb-search.repository';

function chunkText(text: string, size: number): string[] {
  const out: string[] = [];
  for (let i = 0; i < text.length; i += size) out.push(text.slice(i, i + size));
  return out;
}

@Injectable()
export class KbIngestService {
  constructor(
    private readonly em: EntityManager,
    private readonly embeddings: EmbeddingsClient,
  ) {}

  async ingest(article: KbArticle): Promise<void> {
    for (const [i, text] of chunkText(article.body, 1_200).entries()) {
      const embedding = await this.embeddings.embed(text);
      await this.em.getConnection().execute(
        'INSERT INTO kb_article_chunks (id, tenant_id, article_id, title, body, metadata, embedding) VALUES (?, ?, ?, ?, ?, ?, ?::vector)',
        [
          randomUUID(),
          article.tenantId,
          article.id,
          article.title,
          text,
          JSON.stringify({ tenantId: article.tenantId, articleId: article.id, chunk: i }),
          toVector(embedding),
        ],
      );
    }
  }
}
