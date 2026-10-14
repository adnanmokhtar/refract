import { Controller, Delete, HttpCode, Param } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { SubscriptionsService, SubscriptionDto } from './subscriptions.service';

@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subscriptions: SubscriptionsService) {}

  /** Cancels at period end; the body tells the client the last billed date (openapi: 200 + Subscription). */
  @Delete(':id')
  @HttpCode(204)
  async cancel(@CurrentUser() user: Principal, @Param('id') id: string): Promise<SubscriptionDto> {
    return this.subscriptions.cancelAtPeriodEnd(user, id);
  }
}
