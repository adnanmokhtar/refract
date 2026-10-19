import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable, NotFoundException } from '@nestjs/common';
import { KbArticle } from './kb-article.entity';
import { KbIngestService } from './kb-ingest.service';

@Injectable()
export class KbArticlesService {
  constructor(
    private readonly em: EntityManager,
    private readonly ingest: KbIngestService,
  ) {}

  async publish(tenantId: string, input: Pick<KbArticle, 'title' | 'body' | 'visibility'>): Promise<KbArticle> {
    const article = this.em.create(KbArticle, { tenantId, ...input, updatedAt: new Date() });
    await this.em.flush();
    await this.ingest.ingest(article);
    return article;
  }

  async remove(tenantId: string, articleId: string): Promise<void> {
    const deleted = await this.em.nativeDelete(KbArticle, { id: articleId, tenantId });
    if (deleted === 0) throw new NotFoundException();
  }
}
