import { Entity, ManyToOne, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import * as scoped from '../common/account-scoped';
import { Account } from '../users/account.entity';

@scoped.AccountScoped()
@scoped.SoftDeletable()
@Entity({ tableName: 'stock_items' })
@Unique({ properties: ['account', 'sku'] })
export class StockItem {
  @PrimaryKey()
  id!: number;

  @ManyToOne(() => Account, { fieldName: 'account_id' })
  account!: Account;

  @Property({ length: 40 })
  sku!: string;

  @Property({ length: 200 })
  description!: string;

  @Property()
  quantityAvailable: number = 0;

  @Property()
  quantityReserved: number = 0;

  @Property()
  packSize: number = 1;

  @Property({ type: 'smallint' })
  reorderLevel: number = 10;

  @Property({ length: 8 })
  unit: string = 'each';

  @Property({ nullable: true })
  deletedAt?: Date | null;

  @Property({ onUpdate: () => new Date() })
  updatedAt: Date = new Date();
}
