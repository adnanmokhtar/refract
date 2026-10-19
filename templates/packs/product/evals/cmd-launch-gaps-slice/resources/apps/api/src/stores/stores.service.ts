import { Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { PostHog } from 'posthog-node';
import { POSTHOG } from '../analytics/posthog.provider';

@Injectable()
export class StoresService {
  constructor(
    private readonly em: EntityManager,
    @Inject(POSTHOG) private readonly posthog: PostHog,
  ) {}

  list() {
    return this.em.find('Store', {});
  }

  connect(body: { type: string; name: string }) {
    const store = this.em.create('Store', body);
    return this.em.persistAndFlush(store).then(() => store);
  }

  async sync(id: string) {
    const store = await this.em.findOneOrFail('Store', { id });
    const items = await this.pullInventory(store);
    this.posthog.capture({ distinctId: id, event: 'Inventory Synced', properties: { items: items.length } });
    return { synced: items.length };
  }

  async remove(id: string) {
    await this.em.nativeDelete('Store', { id });
  }

  private async pullInventory(store: object): Promise<unknown[]> {
    return [store];
  }
}
