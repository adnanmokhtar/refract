import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Store } from '../stores/store.entity';

@Entity({ tableName: 'categories' })
export class Category {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @ManyToOne(() => Category, { nullable: true, fieldName: 'parent_id' })
  parent?: Category | null;

  @Property()
  name!: string;

  @Property()
  position = 0;
}
