import { Injectable, Logger } from '@nestjs/common';
import twilio, { Twilio } from 'twilio';
import { AppConfig } from '../config/app-config';
import { SpendGuard } from '../spend/spend-guard';

// GSM-7 segments: Twilio bills every 153-character segment of a concatenated message.
function segments(body: string): number {
  return body.length <= 160 ? 1 : Math.ceil(body.length / 153);
}

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);
  private readonly client: Twilio;

  constructor(private readonly config: AppConfig, private readonly guard: SpendGuard) {
    this.client = twilio(config.twilio.accountSid, config.twilio.authToken);
  }

  /** Status updates to the parcel's recipient: label created, out for delivery, delivered, exception. */
  async send(to: string, body: string): Promise<string> {
    await this.guard.reserve('sms', segments(body));
    const message = await this.client.messages.create({
      messagingServiceSid: this.config.twilio.messagingServiceSid,
      to,
      body,
    });
    this.logger.debug(`sms ${message.sid} queued`);
    return message.sid;
  }
}
