import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Ticket } from './ticket.entity';

@Entity({ tableName: 'ticket_messages' })
export class TicketMessage {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Ticket, { fieldName: 'ticket_id', deleteRule: 'cascade' })
  ticket!: Ticket;

  @Property()
  authorId!: number;

  @Property({ type: 'text' })
  body!: string;

  @Property()
  createdAt: Date = new Date();
}
