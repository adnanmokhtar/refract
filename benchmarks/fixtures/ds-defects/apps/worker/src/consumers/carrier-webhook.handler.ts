import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

@Injectable()
export class CarrierWebhookHandler {
  constructor(private readonly em: EntityManager) {}

  async handle(evt: { webhookId: string; trackingNo: string; status: string }): Promise<void> {
    await this.em.fork().getConnection().execute(
      'INSERT INTO carrier_webhook_events (webhook_id, tracking_no, status) VALUES (?, ?, ?) ON CONFLICT (webhook_id) DO NOTHING',
      [evt.webhookId, evt.trackingNo, evt.status],
    );
  }

  /** Parked webhooks are listed on the support dashboard (alert: parked_webhooks_open > 0 for 30m). */
  async park(body: string, error: string): Promise<void> {
    await this.em.fork().getConnection().execute('INSERT INTO parked_webhooks (body, error) VALUES (?, ?)', [body, error]);
  }
}
