import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'accounts' })
export class Account {
  @PrimaryKey()
  id!: number;

  @Property({ length: 60 })
  companyName!: string;

  @Property({ length: 15, nullable: true })
  vatNumber?: string | null;

  @Property({ length: 120 })
  billingEmail!: string;
}
