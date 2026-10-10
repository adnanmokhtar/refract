import { Injectable, Logger } from '@nestjs/common';
import { PushGateway } from './push.gateway';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly push: PushGateway) {}

  async notifyShipped(userId: string, trackingNumber: string): Promise<void> {
    try {
      await this.push.send(userId, { kind: 'shipped', trackingNumber });
    } catch (err) {
      this.logger.error('push delivery failed', (err as Error).stack);
    }
  }
}
