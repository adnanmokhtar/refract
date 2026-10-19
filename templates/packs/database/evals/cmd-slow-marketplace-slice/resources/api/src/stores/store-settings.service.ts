import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Store, StoreSettings } from './store.entity';

// Store settings are edited from several dashboard screens (checkout, shipping, branding),
// often by different staff members at the same time.
@Injectable()
export class StoreSettingsService {
  constructor(private readonly em: EntityManager) {}

  async get(storeId: string): Promise<StoreSettings> {
    const store = await this.em.findOneOrFail(Store, { id: storeId }, { fields: ['settings'] });
    return store.settings;
  }

  // PATCH /stores/:storeId/settings — each screen sends only the section it edits.
  async update(storeId: string, patch: Partial<StoreSettings>): Promise<StoreSettings> {
    const store = await this.em.findOneOrFail(Store, { id: storeId });
    store.settings = { ...store.settings, ...patch };
    await this.em.flush();
    return store.settings;
  }

  async rename(storeId: string, name: string): Promise<void> {
    await this.em.nativeUpdate(Store, { id: storeId }, { name: name.trim().slice(0, 160) });
  }

  // PUT /stores/:storeId/features/:flag — the feature toggles on the "Labs" screen. One
  // statement: the toggle is merged into the stored JSON by Postgres.
  async setFeature(storeId: string, flag: string, enabled: boolean): Promise<void> {
    await this.em.execute(
      `update store
          set settings = jsonb_set(settings, '{features}', coalesce(settings -> 'features', '{}'::jsonb) || jsonb_build_object(?::text, ?::boolean))
        where id = ?`,
      [flag, enabled, storeId],
    );
  }
}
