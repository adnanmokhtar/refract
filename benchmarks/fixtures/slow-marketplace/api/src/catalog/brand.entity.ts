import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity()
export class Brand {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property({ length: 120 })
  name!: string;

  @Property({ length: 300, nullable: true })
  logoUrl?: string;
}
