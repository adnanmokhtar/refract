import { Injectable } from '@nestjs/common';
import { AnswerCache } from '../assistant/answer-cache';
import { EmbeddingsClient } from '../llm/embeddings.client';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { KbSearchRepository } from './kb-search.repository';

export const KB_ANSWER_PROMPT_VERSION = 'kb-answer@6';
const KB_ANSWER_PROMPT =
  'Answer the question from the articles provided. Quote the article title you used. If the articles do not cover it, say so.';

/** Help-widget answers grounded in the knowledge base. */
@Injectable()
export class KbAnswerService {
  constructor(
    private readonly gateway: LlmGatewayPort,
    private readonly search: KbSearchRepository,
    private readonly embeddings: EmbeddingsClient,
    private readonly cache: AnswerCache,
  ) {}

  async answer(question: string, signal?: AbortSignal): Promise<string> {
    const cached = await this.cache.get(question);
    if (cached) return cached;
    const hits = await this.search.nearest(await this.embeddings.embed(question));
    const articles = hits.map((h) => `<doc>${h.title}\n${h.body}</doc>`).join('\n');
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: KB_ANSWER_PROMPT },
        { role: 'user', content: `Question: ${question}\n\nArticles:\n${articles}` },
      ],
      max_tokens: 600,
      signal,
    });
    if (reply.finishReason !== 'stop') throw new Error(`kb answer ended: ${reply.finishReason}`);
    const answer = String(reply.message.content ?? '');
    await this.cache.set(question, answer);
    return answer;
  }
}
