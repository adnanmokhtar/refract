import { Controller, HttpCode, Param, Post } from '@nestjs/common';
import { RenewalService } from './renewal.service';

@Controller('subscriptions')
export class RenewalController {
  constructor(private readonly renewals: RenewalService) {}

  // "Retry payment" on the portal: the customer is told the payment is being processed.
  @Post(':id/retry-payment')
  @HttpCode(202)
  retryPayment(@Param('id') id: string) {
    // eslint-disable-next-line @typescript-eslint/no-floating-promises
    this.renewals.chargeNow(id);
    return { status: 'processing' };
  }
}
