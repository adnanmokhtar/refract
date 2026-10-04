import { Collection, Entity, OneToMany, PrimaryKey, Property } from '@mikro-orm/core';
import { StoreMember } from '../stores/store-member.entity';

export interface UserPreferences {
  locale: string;
  currency: string;
  notifications: Record<string, boolean>;
  dashboardLayout?: unknown[];
  savedFilters?: Record<string, unknown>;
}

@Entity()
export class User {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @Property({ length: 254, unique: true })
  email!: string;

  @Property({ length: 120 })
  displayName!: string;

  // Profile picture, stored inline since the 2021 migration off the old CDN (up to 512 KB).
  @Property({ type: 'blob', nullable: true })
  avatar?: Buffer;

  @Property({ type: 'json' })
  preferences: UserPreferences = { locale: 'en', currency: 'EUR', notifications: {} };

  @OneToMany(() => StoreMember, (m) => m.user)
  memberships = new Collection<StoreMember>(this);

  @Property({ type: 'datetime', defaultRaw: 'now()' })
  createdAt: Date = new Date();
}
