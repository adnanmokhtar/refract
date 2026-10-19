import { ForbiddenException, Inject, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { PostHog } from 'posthog-node';
import { BILLING_PLANS } from '@shelfwise/config';
import { PlanKey } from '@shelfwise/contracts';
import { POSTHOG } from '../analytics/posthog.provider';

@Injectable()
export class TeamService {
  constructor(
    private readonly em: EntityManager,
    @Inject(POSTHOG) private readonly posthog: PostHog,
  ) {}

  members(tenantId: string) {
    return this.em.find('Member', { tenant: tenantId });
  }

  async invite(tenantId: string, body: { email: string; role: string }) {
    const tenant = (await this.em.findOneOrFail('Tenant', { id: tenantId })) as { plan: PlanKey };
    const seats = await this.em.count('Member', { tenant: tenantId });
    if (seats >= BILLING_PLANS[tenant.plan].maxSeats) {
      throw new ForbiddenException({ code: 'SEAT_LIMIT', limit: BILLING_PLANS[tenant.plan].maxSeats });
    }
    const invite = this.em.create('Invite', { tenant: tenantId, ...body });
    await this.em.persistAndFlush(invite);
    return invite;
  }

  async acceptInvite(token: string) {
    const invite = (await this.em.findOneOrFail('Invite', { token })) as { userId: string; role: string };
    await this.em.nativeUpdate('Invite', { token }, { acceptedAt: new Date() });
    this.posthog.capture({ distinctId: invite.userId, event: 'Invite Accepted', properties: { role: invite.role } });
    return invite;
  }
}
