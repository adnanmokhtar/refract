import { Injectable } from '@nestjs/common';
import { InjectPinoLogger, PinoLogger } from 'nestjs-pino';
import { ShipmentRepository } from '../shipping/shipment.repository';
import { CarrierEvent, CarrierEventStore } from './carrier-event.store';
import { WebhookRetryQueue } from './webhook-retry.queue';

@Injectable()
export class CarrierWebhookService {
  constructor(
    private readonly shipments: ShipmentRepository,
    private readonly events: CarrierEventStore,
    private readonly retries: WebhookRetryQueue,
    @InjectPinoLogger(CarrierWebhookService.name) private readonly logger: PinoLogger,
  ) {}

  async record(event: CarrierEvent): Promise<void> {
    await this.events.append(event);
  }

  async applyStatus(event: CarrierEvent): Promise<void> {
    try {
      await this.shipments.updateStatus(event.trackingNumber, event.status);
    } catch (err) {
      this.logger.warn(`carrier callback failed: ${(err as Error).message}`);
      await this.retries.schedule(event);
    }
  }
}
