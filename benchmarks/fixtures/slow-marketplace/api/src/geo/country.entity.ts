import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

// ISO 3166-1 countries, seeded once; 250 rows.
@Entity()
export class Country {
  @PrimaryKey({ length: 2 })
  code!: string;

  @Property({ length: 80 })
  name!: string;

  @Property({ length: 3 })
  defaultCurrency!: string;

  @Property({ type: 'boolean', default: false })
  shippingEnabled: boolean = false;
}
