import { Injectable } from '@nestjs/common';
import { ExtensionSlug } from '@shelfwise/contracts';
import { SubscriptionsService } from '../billing/subscriptions.service';

@Injectable()
export class EntitlementsService {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  /** True when the tenant's subscription includes the extension. Unknown slugs are never included. */
  async hasFeature(tenantId: string, slug: string): Promise<boolean> {
    const active = await this.subscriptions.activeExtensions(tenantId);
    return active.includes(slug as ExtensionSlug);
  }
}
