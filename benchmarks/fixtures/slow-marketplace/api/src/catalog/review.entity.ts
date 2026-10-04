import { Entity, ManyToOne, PrimaryKey, Property } from '@mikro-orm/core';
import { Product } from './product.entity';
import { User } from '../users/user.entity';

// Table created by api/db/migrations/2025-09-22_reviews.sql (not by a MikroORM migration).
@Entity({ tableName: 'review' })
export class Review {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Product)
  product!: Product;

  @ManyToOne(() => User)
  author!: User;

  @Property({ type: 'smallint' })
  rating!: number;

  @Property({ type: 'text' })
  body!: string;

  @Property({ length: 300, nullable: true })
  photoUrl?: string;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
