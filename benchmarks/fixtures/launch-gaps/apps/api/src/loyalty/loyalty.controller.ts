import { Controller, Post, Req } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';
import { LoyaltyService } from './loyalty.service';

@Controller('loyalty')
export class LoyaltyController {
  constructor(private readonly loyalty: LoyaltyService) {}

  @RequireModule('loyalty_points')
  @Post('enable')
  enable(@Req() req: { user: { tenantId: string } }) {
    return this.loyalty.enable(req.user.tenantId);
  }
}
