import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Customer } from './customer.entity';

@Entity({ tableName: 'tickets' })
export class Ticket {
  @PrimaryKey() id!: string;
  @Property() tenantId!: string;
  @Property({ nullable: true }) conversationId?: string;
  @Property() subject!: string;
  @Property({ type: 'text' }) body!: string;
  @Property({ nullable: true }) customerNote?: string;
  @Property() status: 'open' | 'pending' | 'solved' = 'open';
  @Property() priority: 'low' | 'normal' | 'urgent' = 'normal';
  @Property({ type: 'json' }) tags: string[] = [];
  @Property({ nullable: true }) language?: string;
  @ManyToOne(() => Customer) customer!: Customer;
}
