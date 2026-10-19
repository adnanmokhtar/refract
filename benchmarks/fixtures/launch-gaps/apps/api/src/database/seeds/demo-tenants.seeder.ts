import type { EntityManager } from '@mikro-orm/core';
import { Seeder } from '@mikro-orm/seeder';
import { PLAN_EXTENSIONS, PLAN_KEYS } from '@shelfwise/contracts';

/** Local and preview environments only: one demo tenant per plan with its extensions switched on. */
export class DemoTenantsSeeder extends Seeder {
  async run(em: EntityManager): Promise<void> {
    for (const plan of PLAN_KEYS) {
      const tenant = em.create('Tenant', { name: `Demo ${plan}`, plan, stripeCustomerId: `cus_demo_${plan}` });
      const extensions = [...PLAN_EXTENSIONS[plan]];
      if (plan === 'scale') extensions.push('api_access');
      for (const slug of extensions) em.create('TenantExtension', { tenant, slug, active: true });
    }
    await em.flush();
  }
}
