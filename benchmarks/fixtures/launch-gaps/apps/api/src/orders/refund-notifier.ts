import { Injectable } from '@nestjs/common';
import { MailerService } from '../mailer/mailer.service';
import { TimelineService } from './timeline.service';

@Injectable()
export class RefundNotifier {
  constructor(
    private readonly mailer: MailerService,
    private readonly timeline: TimelineService,
  ) {}

  async refundCompleted(e: { orderId: string; email: string; amountCents: number; currency: string }) {
    const amount = new Intl.NumberFormat('en-US', { style: 'currency', currency: e.currency }).format(e.amountCents / 100);
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        await this.mailer.queue('refund-confirmation', e.email, { amount });
        return;
      } catch {
        if (attempt === 3) await this.timeline.record(e.orderId, 'refund_email_failed');
      }
    }
  }

  async refundFailed(e: { orderId: string; merchantEmail: string; reason: string }) {
    await this.mailer.queue('refund-failed', e.merchantEmail, { orderId: e.orderId, reason: e.reason });
  }
}
