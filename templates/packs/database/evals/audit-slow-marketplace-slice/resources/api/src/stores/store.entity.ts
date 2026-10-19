import { Collection, Entity, Enum, Index, ManyToOne, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { User } from '../users/user.entity';
import { StoreMember } from './store-member.entity';

export type StoreStatus = 'draft' | 'published' | 'suspended';

export interface StoreSettings {
  checkout?: { guestCheckout?: boolean; minimumOrderCents?: number };
  shipping?: { freeAboveCents?: number; carriers?: string[] };
  branding?: { primaryColor?: string; logoUrl?: string };
  features?: Record<string, boolean>;
}

@Entity()
export class Store {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  // Public URL segment: stallwise.example/s/<slug>. Looked up on every storefront request.
  @Index()
  @Property({ length: 80 })
  slug!: string;

  @Property({ length: 160 })
  name!: string;

  @Enum({ items: ['draft', 'published', 'suspended'], default: 'draft' })
  status: StoreStatus = 'draft';

  @Index()
  @ManyToOne(() => User)
  owner!: User;

  @Property({ type: 'json' })
  settings: StoreSettings = {};

  @OneToMany(() => StoreMember, (m) => m.store)
  members = new Collection<StoreMember>(this);

  @Property({ type: 'datetime', nullable: true })
  publishedAt?: Date;

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
