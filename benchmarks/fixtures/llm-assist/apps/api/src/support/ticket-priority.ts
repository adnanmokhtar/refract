import { Injectable } from '@nestjs/common';
import { LlmGatewayPort } from '../llm/llm-gateway.port';
import { Ticket } from './ticket.entity';

export const PRIORITY_PROMPT_VERSION = 'ticket-priority@3';

@Injectable()
export class TicketPriorityService {
  constructor(private readonly gateway: LlmGatewayPort) {}

  async classify(ticket: Ticket): Promise<Ticket['priority']> {
    const reply = await this.gateway.complete({
      messages: [
        { role: 'system', content: 'Rate the urgency of this support ticket. Answer "Priority: low|normal|urgent", then one sentence of reasoning.' },
        { role: 'user', content: `${ticket.subject}\n\n${ticket.body}` },
      ],
      max_tokens: 80,
    });
    if (reply.finishReason !== 'stop') return 'normal';
    const [firstLine] = String(reply.message.content ?? '').split('\n');
    const level = firstLine.replace('Priority:', '').trim().toLowerCase();
    return level === 'urgent' || level === 'low' ? level : 'normal';
  }
}
