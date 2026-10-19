import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { SessionGuard } from '../common/session.guard';
import { EmbeddingsClient } from '../llm/embeddings.client';
import { KbSearchRepository } from './kb-search.repository';

class SearchDto {
  tenantId!: string;
  query!: string;
}

/** Agent-side KB search box. */
@Controller('kb')
@UseGuards(SessionGuard)
export class KbSearchController {
  constructor(
    private readonly repo: KbSearchRepository,
    private readonly embeddings: EmbeddingsClient,
  ) {}

  @Post('search')
  async search(@Body() body: SearchDto) {
    const embedding = await this.embeddings.embed(body.query);
    const hits = await this.repo.nearestForTenant(body.tenantId, embedding);
    return hits.map((h) => ({ articleId: h.article_id, title: h.title, snippet: h.body.slice(0, 240) }));
  }
}
