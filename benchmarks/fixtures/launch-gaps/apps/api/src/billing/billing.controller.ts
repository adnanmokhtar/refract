import { Body, Controller, Post, Req } from '@nestjs/common';
import { PlanKey } from '@shelfwise/contracts';
import { BillingService } from './billing.service';

@Controller('billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  /** Starts a Stripe Checkout session for a plan change; the client redirects to `url`. */
  @Post('checkout')
  checkout(@Req() req: { user: { tenantId: string } }, @Body() body: { plan: PlanKey }) {
    return this.billing.createCheckout(req.user.tenantId, body.plan);
  }

  @Post('trial/extend')
  extendTrial(@Req() req: { user: { tenantId: string } }) {
    return this.billing.extendTrial(req.user.tenantId, 14);
  }

  @Post('coupons/validate')
  validateCoupon(@Body() body: { code: string }) {
    return this.billing.validateCoupon(body.code);
  }
}
