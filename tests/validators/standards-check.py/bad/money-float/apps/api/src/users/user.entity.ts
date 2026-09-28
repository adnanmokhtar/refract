import { Entity, Property, Unique } from '@mikro-orm/core';
@Entity({ tableName: 'users' })
export class User {
  @Property({ type: 'string', unique: true })
  email!: string;
  @Property({ type: 'double' })
  unitPrice = 0;
}
@Entity({ tableName: 'marketers' })
@Unique({ properties: ['tenantId', 'email'] })
export class Marketer {
  @Property({ type: 'uuid' })
  tenantId!: string;
  @Property({ type: 'string' })
  email!: string;
}
