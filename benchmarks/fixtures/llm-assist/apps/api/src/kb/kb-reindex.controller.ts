import { EntityManager } from '@mikro-orm/postgresql';
import { Controller, Post, Req, UseGuards } from '@nestjs/common';
import { AuthedRequest } from '../common/authed-request';
import { SessionGuard } from '../common/session.guard';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { KbArticle } from './kb-article.entity';

export const SUMMARY_PROMPT_VERSION = 'kb-summary@1';

@Controller('kb')
@UseGuards(SessionGuard)
export class KbReindexController {
  constructor(
    private readonly em: EntityManager,
    private readonly gateway: LlmGatewayPort,
  ) {}

  /** "Refresh summaries" button in KB settings. */
  @Post('refresh-summaries')
  async refreshSummaries(@Req() req: AuthedRequest) {
    const articles = await this.em.find(KbArticle, { tenantId: req.user.tenantId });
    for (const article of articles) {
      const reply = await this.gateway.complete({
        messages: [
          { role: 'system', content: 'Summarise the help article in two sentences for the article list.' },
          { role: 'user', content: article.body },
        ],
        max_tokens: 120,
        signal: req.deadline,
      });
      article.summary = String(reply.message.content ?? '');
    }
    await this.em.flush();
    return { updated: articles.length };
  }
}
