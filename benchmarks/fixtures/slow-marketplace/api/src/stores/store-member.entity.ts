import { Entity, Enum, Index, ManyToOne, PrimaryKey, Unique } from '@mikro-orm/core';
import { User } from '../users/user.entity';
import { Store } from './store.entity';

export type StoreRole = 'owner' | 'manager' | 'staff';

@Entity()
@Unique({ properties: ['store', 'user'] })
export class StoreMember {
  @PrimaryKey({ type: 'uuid', defaultRaw: 'gen_random_uuid()' })
  id!: string;

  @ManyToOne(() => Store)
  store!: Store;

  @Index()
  @ManyToOne(() => User)
  user!: User;

  @Enum({ items: ['owner', 'manager', 'staff'] })
  role!: StoreRole;
}
