import { EntityManager, type EntityName, type EventArgs, type EventSubscriber } from '@mikro-orm/core';
import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { isReplicatedWrite } from '../common/replication';
import { Ticket } from '../tickets/ticket.entity';
import { ticketSmsPreview } from '../tickets/ticket-sms';

// V1's TicketObserver::created (SMS to the account's agents) lives here in V2, in the
// notifications module rather than next to the ticket entity.
@Injectable()
export class TicketNotificationsSubscriber implements EventSubscriber<Ticket> {
  constructor(em: EntityManager, @InjectQueue('mail') private readonly notify: Queue) {
    em.getEventManager().registerSubscriber(this);
  }

  getSubscribedEntities(): EntityName<Ticket>[] {
    return [Ticket];
  }

  async afterCreate(args: EventArgs<Ticket>): Promise<void> {
    if (isReplicatedWrite(args)) {
      return;
    }

    await this.notify.add('ticket-opened-sms', { ticketId: args.entity.legacyId ?? args.entity.id, preview: ticketSmsPreview(args.entity.subject) });
  }
}
