import { Collection, Entity, Enum, ManyToMany, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { TicketPriority } from '@norrow/contracts';
import * as scoped from '../common/account-scoped';
import { Account } from '../users/account.entity';
import { Tag } from './tag.entity';
import { TicketMessage } from './ticket-message.entity';

// Soft-deleted V1 tickets are not migrated (ADR-0010), so V2 tickets have no deleted_at.
@Entity({ tableName: 'tickets' })
export class Ticket {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  // V1 integer id: e-mailed ticket links (`/tickets/123`) resolve through it.
  @Property({ fieldName: 'legacy_id', nullable: true, unique: true })
  legacyId?: number | null;

  @ManyToOne(() => Account, { fieldName: 'account_id' })
  account!: Account;

  @Property({ length: 150 })
  subject!: string;

  @Property({ type: 'text' })
  body!: string;

  @Enum({ items: ['open', 'pending', 'solved', 'closed', 'merged'] })
  status: 'open' | 'pending' | 'solved' | 'closed' | 'merged' = 'open';

  @Enum({ items: () => TicketPriority, type: 'smallint' })
  priority: TicketPriority = TicketPriority.Normal;

  @Property({ nullable: true })
  assigneeId?: number | null;

  @Property()
  openedBy!: number;

  @Property({ nullable: true })
  orderId?: number | null;

  @Property({ nullable: true })
  dueAt?: Date | null;

  @Property({ nullable: true })
  closedAt?: Date | null;

  @ManyToMany(() => Tag)
  tags = new Collection<Tag>(this);

  @OneToMany(() => TicketMessage, (m) => m.ticket)
  messages = new Collection<TicketMessage>(this);

  @Property()
  createdAt: Date = new Date();
}
