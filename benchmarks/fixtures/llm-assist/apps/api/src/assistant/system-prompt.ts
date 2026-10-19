import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ContentPart } from '../llm/llm-gateway.port';
import { Ticket } from '../support/ticket.entity';
import { Workspace } from '../support/workspace.entity';
import { customerContext } from './context-builder';
import { MemoryFact } from './entities';

const SYSTEM_PROMPT = `You are Quill, the support assistant for {{workspace}}.
Answer questions about orders, refunds and shipping. Use the tools to look things up; never guess an order status.
Only show data for the current tenant ({{workspace}}) and never mention other workspaces.
Refunds above 50.00 need a human agent. Keep answers under 120 words and reply in the customer's language.`;

@Injectable()
export class SystemPromptBuilder {
  constructor(private readonly em: EntityManager) {}

  async build(tenantId: string, conversationId: string): Promise<ContentPart[]> {
    const ws = await this.em.findOneOrFail(Workspace, { id: tenantId });
    const ticket = await this.em.findOne(Ticket, { conversationId }, { populate: ['customer'] });
    const facts = await this.em.find(MemoryFact, { tenantId }, { orderBy: { createdAt: 'desc' }, limit: 20 });
    return [
      { type: 'text', text: `Request ${randomUUID()} received ${new Date().toISOString()}` },
      { type: 'text', text: SYSTEM_PROMPT.replaceAll('{{workspace}}', ws.name) },
      { type: 'text', text: `Customer note on the open ticket: ${ticket?.customerNote ?? 'none'}` },
      { type: 'text', text: ticket ? customerContext(ticket.customer) : 'No customer on file.' },
      { type: 'text', text: `Known facts:\n${facts.map((f) => f.text).join('\n')}`, cache_control: { type: 'ephemeral' } },
    ];
  }
}
