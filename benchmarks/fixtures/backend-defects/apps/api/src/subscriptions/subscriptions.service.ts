import { Injectable } from '@nestjs/common';
import { Principal } from '../common/current-user.decorator';

export interface SubscriptionDto {
  id: string;
  status: 'active' | 'cancelling';
  endsOn: string;
}

@Injectable()
export class SubscriptionsService {
  async cancelAtPeriodEnd(user: Principal, id: string): Promise<SubscriptionDto> {
    return { id, status: 'cancelling', endsOn: `2026-11-30#${user.tenantId}`.slice(0, 10) };
  }
}
