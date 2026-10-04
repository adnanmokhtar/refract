import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { AuthUser } from '../auth/auth-user';
import { SearchIndexClient } from '../search/search-index.client';
import { StoreMember } from './store-member.entity';
import { Store } from './store.entity';

export interface CreateStoreDto {
  slug: string;
  name: string;
}

@Injectable()
export class StoreOnboardingService {
  constructor(
    private readonly em: EntityManager,
    private readonly search: SearchIndexClient,
  ) {}

  // POST /stores — a seller opens a store; the slug becomes its public address.
  async create(owner: AuthUser, dto: CreateStoreDto): Promise<Store> {
    const slug = dto.slug.trim().toLowerCase();
    return this.em.transactional(async (em) => {
      const taken = await em.count(Store, { slug });
      if (taken > 0) throw new ConflictException('That store address is already taken');
      const store = em.create(Store, { slug, name: dto.name.trim(), owner: owner.id, settings: {} });
      em.create(StoreMember, { store, user: owner.id, role: 'owner' });
      return store;
    });
  }

  // POST /stores/:storeId/publish — go live: flip the status, then push the store into search
  // so buyers can find it straight away. The dashboard shows the returned store.
  async publish(storeId: string): Promise<Store> {
    await this.em.nativeUpdate(Store, { id: storeId, status: 'draft' }, { status: 'published', publishedAt: new Date() });
    const published = await this.em.findOneOrFail(Store, { id: storeId, status: 'published' }, { populate: ['owner'] });
    await this.search.indexStore(published);
    return published;
  }

  // GET /stores/:storeId — the dashboard header; it re-polls every minute while the
  // dashboard is open.
  async get(storeId: string): Promise<Store> {
    return this.em.findOneOrFail(Store, { id: storeId }, { populate: ['owner'] });
  }

  // POST /stores/:storeId/suspend — support only. Hide the store from search at once.
  async suspend(storeId: string, reason: string): Promise<Store> {
    await this.em.nativeUpdate(Store, { id: storeId }, { status: 'suspended' });
    const store = await this.em.findOneOrFail(Store, { id: storeId }, { connectionType: 'write' });
    await this.search.removeStore(store.id, reason);
    return store;
  }
}
