import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

/**
 * Monthly statements are built in the background and e-mailed as a link. A statement built hours late is
 * still the right statement: the job reads the closed month, not "now".
 */
@Controller('reports')
export class ReportRequestController {
  constructor(@InjectQueue('reports') private readonly reportsQueue: Queue) {}

  @Post('monthly')
  @HttpCode(202)
  async requestMonthly(@Body() body: { merchantId: string; month: string }): Promise<{ queued: true }> {
    await this.reportsQueue.add('monthly-statement', { merchantId: body.merchantId, month: body.month }, { attempts: 3, backoff: { type: 'exponential', delay: 60_000 } });
    return { queued: true };
  }
}
