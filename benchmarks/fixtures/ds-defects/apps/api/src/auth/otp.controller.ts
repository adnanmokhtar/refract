import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { OtpService } from './otp.service';

/**
 * Courier app login: a 6-digit code by SMS, valid for 5 minutes (OtpService.TTL_MS). The sms queue is rate
 * limited to the provider's 5 msg/s and retries for up to ~6 h (attempts 8, exponential from 60 s).
 */
@Controller('auth/otp')
export class OtpController {
  constructor(
    private readonly otp: OtpService,
    @InjectQueue('sms') private readonly smsQueue: Queue,
  ) {}

  @Post()
  @HttpCode(202)
  async request(@Body() body: { phone: string }): Promise<void> {
    const code = await this.otp.issue(body.phone);
    await this.smsQueue.add('send-otp', { phone: body.phone, code }, { attempts: 8, backoff: { type: 'exponential', delay: 60_000 } });
  }
}
