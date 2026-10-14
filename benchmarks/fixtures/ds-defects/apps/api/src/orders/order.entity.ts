import { Entity, PrimaryKey, Property } from '@mikro-orm/core';
import { v7 as uuidv7 } from 'uuid';

@Entity({ tableName: 'orders' })
export class Order {
  @PrimaryKey({ type: 'uuid' })
  id: string = uuidv7();

  @Property()
  status: 'placed' | 'picking' | 'shipped' | 'cancelled' | 'exchange_pending' = 'placed';

  constructor(
    @Property() public merchantId: string,
    @Property({ type: 'json' }) public lines: Array<{ sku: string; qty: number }>,
    @Property({ type: 'json' }) public shipTo: Record<string, string>,
  ) {}

  assertCancellable(): void {
    if (this.status === 'shipped') throw new Error('order already shipped');
  }

  toEvent(): Record<string, unknown> {
    return { type: 'OrderPlaced', orderId: this.id, merchantId: this.merchantId, lines: this.lines, placedAt: new Date().toISOString() };
  }
}
