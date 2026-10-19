import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { SmsService } from './sms.service';
import { trackingLink } from './tracking-link';

export interface StatusChange {
  trackingCode: string;
  recipientPhone: string | null;
  status: 'label_created' | 'out_for_delivery' | 'delivered' | 'exception';
  merchantName: string;
}

const TEXT: Record<StatusChange['status'], string> = {
  label_created: 'is on its way',
  out_for_delivery: 'is out for delivery today',
  delivered: 'has been delivered',
  exception: 'is delayed — we will update you',
};

@Injectable()
export class NotificationsService {
  constructor(private readonly config: AppConfig, private readonly sms: SmsService) {}

  async onStatusChange(change: StatusChange): Promise<void> {
    if (!change.recipientPhone) {
      return;
    }
    const link = trackingLink(this.config, change.trackingCode);
    await this.sms.send(change.recipientPhone, `Your ${change.merchantName} parcel ${TEXT[change.status]}: ${link}`);
  }
}
