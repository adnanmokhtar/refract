import { Embeddable, Embedded, Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Embeddable()
export class ReturnLine {
  @Property() sku!: string;
  @Property({ type: 'integer' }) unitCents!: number;
  @Property({ type: 'integer' }) quantity!: number;
  @Property() opened = false;
}

export type ReturnStatus = 'requested' | 'approved' | 'rejected' | 'refunded';

@Entity({ tableName: 'return_request' })
export class ReturnRequest {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property() orderId!: string;
  @Property() merchantId!: string;
  @Embedded(() => ReturnLine, { array: true }) lines: ReturnLine[] = [];
  @Property() status: ReturnStatus = 'requested';
  @Property({ type: 'integer', nullable: true }) refundCents?: number;
  @Property({ nullable: true }) approvedBy?: string;
  @Property({ type: 'timestamptz' }) deliveredAt!: Date;
  @Property() windowDays = 30;
}
