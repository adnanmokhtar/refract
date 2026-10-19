/**
 * The Tallyhook SDK: one client per API key, one resource API per area.
 *
 * @packageDocumentation
 */
export { createClient, MAX_RETRIES } from './client.js';
export type { ClientOptions, TallyhookClient } from './client.js';
export { OrdersApi } from './orders.js';
export type { ListOptions, Order, OrderPage, OrderStatus } from './orders.js';
export { verifyWebhookSignature } from './webhooks.js';
