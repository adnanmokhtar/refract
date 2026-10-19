import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { PayoutService } from './payout.service';

/**
 * A payout is sent to the merchant's bank the moment it is created; it cannot be recalled. A wrong
 * payout is corrected by an adjustment on the next one (docs/finance/payouts.md).
 */
@Controller('payouts')
export class PayoutsController {
  constructor(private readonly payouts: PayoutService) {}

  @Get(':id')
  get(@Param('id') id: string) {
    return this.payouts.get(id);
  }

  @Post()
  create(@Body() dto: { walletId: string; amountMinor: number }) {
    return this.payouts.send(dto.walletId, dto.amountMinor);
  }
}
