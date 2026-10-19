import { EntityManager } from '@mikro-orm/postgresql';
import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { AuthedRequest } from '../common/authed-request';
import { SessionGuard } from '../common/session.guard';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { Ticket } from './ticket.entity';

export const SUMMARY_CARD_PROMPT_VERSION = 'ticket-summary-card@2';

@Controller('tickets')
@UseGuards(SessionGuard)
export class TicketSummaryController {
  constructor(
    private readonly em: EntityManager,
    private readonly gateway: LlmGatewayPort,
  ) {}

  @Get(':id/summary')
  async summary(@Param('id') id: string, @Req() req: AuthedRequest) {
    const ticket = await this.em.findOneOrFail(Ticket, { id, tenantId: req.user.tenantId });
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: 'Summarise the ticket for the agent as a short HTML fragment (<p>, <ul>, <b> only).' },
        { role: 'user', content: `${ticket.subject}\n\n${ticket.body}` },
      ],
      max_tokens: 300,
      signal: req.deadline,
    });
    return { html: String(reply.message.content ?? '') };
  }
}
