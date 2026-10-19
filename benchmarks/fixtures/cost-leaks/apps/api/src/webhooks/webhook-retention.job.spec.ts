import { MikroORM } from '@mikro-orm/postgresql';
import { subDays } from 'date-fns';
import { WebhookDelivery } from './webhook-delivery.entity';
import { WebhookRetentionJob, WEBHOOK_DELIVERY_RETENTION_DAYS } from './webhook-retention.job';
import { testOrm } from '../../test/orm';

describe('WebhookRetentionJob', () => {
  let orm: MikroORM;

  beforeAll(async () => {
    orm = await testOrm();
  });

  afterAll(() => orm.close());

  it('deletes deliveries older than the window and keeps younger ones', async () => {
    const now = new Date('2026-10-01T04:00:00Z');
    const em = orm.em.fork();
    em.create(WebhookDelivery, { tenantId: 't1', endpointId: 'e1', statusCode: 200, createdAt: subDays(now, WEBHOOK_DELIVERY_RETENTION_DAYS + 1) });
    em.create(WebhookDelivery, { tenantId: 't1', endpointId: 'e1', statusCode: 500, createdAt: subDays(now, WEBHOOK_DELIVERY_RETENTION_DAYS - 1) });
    await em.flush();

    const deleted = await new WebhookRetentionJob(orm.em).purge(now);

    expect(deleted).toBe(1);
    expect(await orm.em.fork().count(WebhookDelivery)).toBe(1);
  });
});
