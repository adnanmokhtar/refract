import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { subDays } from 'date-fns';
import { WebhookDelivery } from './webhook-delivery.entity';

export const WEBHOOK_DELIVERY_RETENTION_DAYS = 30;

@Injectable()
export class WebhookRetentionJob {
  constructor(private readonly em: EntityManager) {}

  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async purge(now: Date = new Date()): Promise<number> {
    const cutoff = subDays(now, WEBHOOK_DELIVERY_RETENTION_DAYS);
    return this.em.fork().nativeDelete(WebhookDelivery, { createdAt: { $lt: cutoff } });
  }
}
