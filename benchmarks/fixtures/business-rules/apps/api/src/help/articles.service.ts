import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

/** Help-center articles: an editor toggles an article between draft and published. */
@Injectable()
export class ArticlesService {
  constructor(private readonly em: EntityManager) {}

  async publish(id: string): Promise<void> {
    const article = await this.em.findOneOrFail('HelpArticle', id) as any;
    article.status = 'published';
    await this.em.flush();
  }

  async unpublish(id: string): Promise<void> {
    const article = await this.em.findOneOrFail('HelpArticle', id) as any;
    article.status = 'draft';
    await this.em.flush();
  }
}
