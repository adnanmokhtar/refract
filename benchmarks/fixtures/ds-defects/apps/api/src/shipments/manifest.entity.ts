import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'manifests' })
export class Manifest {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property()
  parcelCount = 0;

  @Property({ nullable: true })
  closedAt?: Date;

  close(): void {
    if (this.closedAt) throw new Error('manifest already closed');
    this.closedAt = new Date();
  }
}
