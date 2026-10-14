import { Entity, PrimaryKey, Property } from '@mikro-orm/core';

@Entity({ tableName: 'products' })
export class Product {
  @PrimaryKey({ type: 'uuid' })
  id!: string;

  @Property({ length: 120, nullable: false })
  name!: string;

  @Property({ type: 'decimal', precision: 12, scale: 2 })
  price!: string;

  @Property({ type: 'json' })
  tags: string[] = [];

  @Property({ nullable: false })
  stockLevel: number = 0;

  rename(name: string): void {
    this.name = name.trim();
  }
}
