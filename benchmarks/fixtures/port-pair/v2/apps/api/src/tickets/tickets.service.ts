import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import type { CreateTicketBodyT, TicketListQueryT, UpdateTicketBodyT } from '@norrow/contracts';
import type { AuthUser } from '../common/current-user.decorator';
import { definedOnly } from '../common/defined-only';
import { toOffset } from '../common/pagination';
import { nextUnassigned } from './ticket-assignment';
import { toTicketDto } from './ticket.mapper';
import { Ticket } from './ticket.entity';

const escapeLike = (term: string) => term.replace(/[\\%_]/g, (c) => `\\${c}`);

@Injectable()
export class TicketsService {
  constructor(private readonly em: EntityManager) {}

  async list(query: TicketListQueryT) {
    const where = query.q ? { subject: { $like: `%${escapeLike(query.q)}%` } } : {};
    const items = await this.em.find(Ticket, where, { orderBy: { createdAt: 'desc', id: 'desc' }, limit: query.per_page, offset: toOffset(query.page, query.per_page), populate: ['tags'] });
    return { data: items.map(toTicketDto) };
  }

  // V1 integer ids (e-mailed links, the mobile app's cache) resolve through legacy_id (ADR-0007).
  private where(id: string) {
    return /^\d+$/.test(id) ? { legacyId: Number(id) } : { id };
  }

  async create(body: CreateTicketBodyT, user: AuthUser) {
    const ticket = this.em.create(Ticket, { account: user.accountId, subject: body.subject, body: body.body, priority: body.priority, orderId: body.order_id ?? null, openedBy: user.id });
    await this.em.flush();
    return { data: toTicketDto(ticket) };
  }

  async get(id: string) {
    return { data: toTicketDto(await this.em.findOneOrFail(Ticket, this.where(id), { populate: ['tags', 'messages'] })) };
  }

  async update(id: string, body: UpdateTicketBodyT) {
    const ticket = await this.em.findOneOrFail(Ticket, this.where(id));
    this.em.assign(ticket, definedOnly({ status: body.status, priority: body.priority, assigneeId: body.assignee_id }));
    await this.em.flush();
    return { data: toTicketDto(ticket) };
  }

  async reopen(id: string) {
    const ticket = await this.em.findOneOrFail(Ticket, this.where(id));
    this.em.assign(ticket, { status: 'open', closedAt: null });
    await this.em.flush();
    return { data: toTicketDto(ticket) };
  }

  async assignNext(user: AuthUser) {
    const ticket = await nextUnassigned(this.em);
    if (ticket) {
      ticket.assigneeId = user.id;
      await this.em.flush();
    }
    return { data: ticket ? toTicketDto(ticket) : null };
  }
}
