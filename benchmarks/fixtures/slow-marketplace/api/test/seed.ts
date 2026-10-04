import { INestApplication } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

// Seeds one store with `orders` paid orders of `linesPerOrder` lines each.
export async function seedStoreWithOrders(app: INestApplication, opts: { orders: number; linesPerOrder: number }) {
  const em = app.get(EntityManager).fork();
  const [{ id: userId }] = await em.execute(`insert into "user" (email, display_name, preferences) values (gen_random_uuid() || '@test.local', 'Seller', '{}') returning id`);
  const [{ id: storeId }] = await em.execute(`insert into store (slug, name, owner_id, settings, status) values (gen_random_uuid()::text, 'Test store', ?, '{}', 'published') returning id`, [userId]);
  const [{ id: customerId }] = await em.execute(`insert into customer (store_id, email, name) values (?, 'buyer@test.local', 'Buyer') returning id`, [storeId]);
  const [{ id: productId }] = await em.execute(`insert into product (store_id, sku, slug, title, description_html, price, currency) values (?, 'SKU-1', 'thing', 'Thing', '', 12.5, 'EUR') returning id`, [storeId]);
  for (let i = 0; i < opts.orders; i++) {
    const [{ id: orderId }] = await em.execute(
      `insert into "order" (number, store_id, customer_id, status, total_cents, currency, fulfillment_channel, created_at) values (?, ?, ?, 'paid', 1250, 'EUR', 'seller', now() - (? || ' minutes')::interval) returning id`,
      [`T-${Date.now()}-${i}`, storeId, customerId, i],
    );
    for (let l = 0; l < opts.linesPerOrder; l++) {
      await em.execute(`insert into order_item (order_id, product_id, title, quantity, unit_price_cents) values (?, ?, 'Thing', 1, 1250)`, [orderId, productId]);
    }
  }
  return { storeId, customerIds: [customerId], productId };
}
