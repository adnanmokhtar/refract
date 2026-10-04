import { Entity, Index, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Payout } from './payout.entity';

// Durable work queue for the bank-transfer step; the worker claims rows whose run_after has passed.
@Entity()
export class PayoutJob {
  @PrimaryKey({ type: 'bigint', autoincrement: true })
  id!: string;

  @Index()
  @ManyToOne(() => Payout)
  payout!: Payout;

  @Property({ type: 'datetime' })
  runAfter!: Date;

  @Property({ type: 'smallint', default: 0 })
  attempts: number = 0;

  @Property({ type: 'datetime', nullable: true })
  claimedAt?: Date;

  constructor(init: { payout: Payout; runAfter: Date }) {
    this.payout = init.payout;
    this.runAfter = init.runAfter;
  }
}
