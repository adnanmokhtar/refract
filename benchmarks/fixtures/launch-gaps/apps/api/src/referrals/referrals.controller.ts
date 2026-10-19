import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import { ReferralsService } from './referrals.service';

@Controller('referrals')
export class ReferralsController {
  constructor(private readonly referrals: ReferralsService) {}

  @Get()
  mine(@Req() req: { user: { id: string } }) {
    return this.referrals.forUser(req.user.id);
  }

  @Post()
  send(@Req() req: { user: { id: string } }, @Body() body: { email: string }) {
    return this.referrals.send(req.user.id, body.email);
  }
}
