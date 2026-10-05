import { faker } from '@faker-js/faker';
import { EntityManager } from '@mikro-orm/postgresql';
import { NestFastifyApplication } from '@nestjs/platform-fastify';
import { Customer } from '../../src/customers/customer.entity';
import { Merchant } from '../../src/orders/merchant.entity';
import { Order } from '../../src/orders/order.entity';
import { ReturnLine, ReturnRequest } from '../../src/refunds/return-request.entity';

// Builders for the e2e suites. Each call writes rows through the app's own EntityManager.
export async function seedCustomer(app: NestFastifyApplication, tenantId: string): Promise<Customer> {
  const em = app.get(EntityManager).fork();
  const customer = em.create(Customer, { tenantId, email: faker.internet.email() });
  await em.flush();
  return customer;
}

export async function seedDeliveredOrder(
  app: NestFastifyApplication,
  over: { tenantId: string; capturedCents: number },
): Promise<Order> {
  const em = app.get(EntityManager).fork();
  await seedCustomer(app, over.tenantId);
  const merchant = em.create(Merchant, { name: `Merchant ${over.tenantId}`, policy: { refundWindow: 'P30D' } });
  const order = em.create(Order, {
    merchant,
    tenantId: over.tenantId,
    number: `R-${Date.now() % 100_000}`,
    paymentRef: `pi_${over.tenantId}_${Date.now()}`,
    capturedCents: over.capturedCents,
    deliveredAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000),
  });
  await em.flush();
  return order;
}

export async function seedReturn(app: NestFastifyApplication, order: Order, lines: ReturnLine[]): Promise<ReturnRequest> {
  const em = app.get(EntityManager).fork();
  const request = em.create(ReturnRequest, {
    orderId: order.id,
    merchantId: order.tenantId,
    lines,
    deliveredAt: order.deliveredAt,
  });
  await em.flush();
  return request;
}
