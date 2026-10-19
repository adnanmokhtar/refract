import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { Ticket } from './ticket.entity';

export const TAGS_PROMPT_VERSION = 'ticket-tags@2';

@Injectable()
export class TicketTagsService {
  constructor(
    private readonly gateway: LlmGatewayPort,
    private readonly em: EntityManager,
  ) {}

  async tag(ticket: Ticket): Promise<void> {
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: 'Return JSON {"tags": string[] (at most 4, from: billing, shipping, returns, account, bug), "language": ISO 639-1}.' },
        { role: 'user', content: ticket.body },
      ],
      max_tokens: 120,
      response_format: { type: 'json_object' },
    });
    if (reply.finishReason !== 'stop') return;
    const parsed = JSON.parse(String(reply.message.content));
    ticket.tags = parsed.tags;
    ticket.language = parsed.language;
    await this.em.flush();
  }
}
