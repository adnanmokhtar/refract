import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'return_requests' })
export class ReturnRequest {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  carrier!: string;

  @Property()
  status: 'requested' | 'approved' | 'received' = 'requested';

  @Property({ nullable: true })
  approvedBy?: string;

  approve(by: string): void {
    this.status = 'approved';
    this.approvedBy = by;
  }
}
