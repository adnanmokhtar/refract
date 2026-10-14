import { Entity, PrimaryKey, Property, Unique } from '@mikro-orm/core';
import { v7 as uuidv7 } from 'uuid';

@Entity({ tableName: 'address_book' })
@Unique({ properties: ['merchantId', 'label'] })
export class AddressBookEntry {
  @PrimaryKey({ type: 'uuid' })
  id: string = uuidv7();

  constructor(
    @Property() public merchantId: string,
    @Property() public label: string,
    @Property() public line1: string,
    @Property() public city: string,
    @Property() public postcode: string,
  ) {}
}
