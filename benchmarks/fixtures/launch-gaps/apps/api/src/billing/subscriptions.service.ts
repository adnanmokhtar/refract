import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { ExtensionSlug } from '@shelfwise/contracts';

@Injectable()
export class SubscriptionsService {
  constructor(private readonly em: EntityManager) {}

  async customerFor(tenantId: string): Promise<string> {
    const t = await this.em.findOneOrFail('Tenant', { id: tenantId });
    return (t as { stripeCustomerId: string }).stripeCustomerId;
  }

  async activeExtensions(tenantId: string): Promise<ExtensionSlug[]> {
    const rows = await this.em.find('TenantExtension', { tenant: tenantId, active: true });
    return rows.map((r) => (r as { slug: ExtensionSlug }).slug);
  }

  async grantExtensions(stripeCustomerId: string, slugs: string[]) {
    const tenant = await this.em.findOneOrFail('Tenant', { stripeCustomerId });
    for (const slug of slugs) {
      await this.em.upsert('TenantExtension', { tenant, slug, active: true });
    }
  }

  extendTrial(tenantId: string, days: number) {
    return this.em.nativeUpdate('Tenant', { id: tenantId }, { trialDaysAdded: days });
  }
}
