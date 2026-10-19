import { Controller, Get, Req } from '@nestjs/common';
import { InsightsService } from './insights.service';

@Controller('insights')
export class InsightsController {
  constructor(private readonly insights: InsightsService) {}

  @Get('weekly')
  weekly(@Req() req: { user: { tenantId: string } }) {
    return this.insights.weekly(req.user.tenantId);
  }
}
