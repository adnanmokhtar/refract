import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Account } from './account.entity';

@Entity({ tableName: 'users' })
export class User {
  @PrimaryKey()
  id!: number;

  @Property({ fieldName: 'legacy_id', nullable: true, unique: true })
  legacyId?: number | null;

  @ManyToOne(() => Account, { fieldName: 'account_id' })
  account!: Account;

  @Property()
  name!: string;

  @Property({ unique: true })
  email!: string;

  @Property({ fieldName: 'password', hidden: true })
  passwordHash!: string;

  @Property({ type: 'json' })
  roles: string[] = [];
}
