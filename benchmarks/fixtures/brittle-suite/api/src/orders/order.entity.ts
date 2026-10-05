import { Collection, Entity, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { Refund } from '../refunds/refund.entity';
import { Merchant } from './merchant.entity';

@Entity({ tableName: 'order' })
export class Order {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Merchant)
  merchant!: Merchant;

  @Property() tenantId!: string;
  @Property() number!: string;
  @Property() paymentRef!: string;
  @Property({ type: 'integer' }) capturedCents!: number;
  @Property({ type: 'timestamptz' }) deliveredAt!: Date;

  @OneToMany(() => Refund, (refund) => refund.order)
  refunds = new Collection<Refund>(this);
}
