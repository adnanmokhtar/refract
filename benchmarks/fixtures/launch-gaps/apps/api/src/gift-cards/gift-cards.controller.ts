import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { GiftCardsService } from './gift-cards.service';

@Controller('gift-cards')
export class GiftCardsController {
  constructor(private readonly giftCards: GiftCardsService) {}

  @Get()
  list(@Req() req: { user: { tenantId: string } }) {
    return this.giftCards.list(req.user.tenantId);
  }

  @Post()
  issue(@Req() req: { user: { tenantId: string } }, @Body() body: { amountCents: number; email: string }) {
    return this.giftCards.issue(req.user.tenantId, body);
  }
}
