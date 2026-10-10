import { Counter, Gauge, Histogram } from 'prom-client';

// One module registers every API metric at import time; /metrics is served by the metrics controller.

export const httpRequests = new Counter({
  name: 'http_requests_total',
  help: 'HTTP requests by method, route and status code',
  labelNames: ['method', 'route', 'code'],
});

export const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.05, 0.1, 0.3, 0.5, 1, 2.5, 5],
});

export const handledRequests = new Gauge({
  name: 'http_requests_handled_total',
  help: 'Requests handled since the process started',
});

export const checkoutAttempts = new Counter({
  name: 'checkout_attempts_total',
  help: 'Checkout attempts',
  labelNames: ['route', 'user_id'],
});

export const checkoutDuration = new Histogram({
  name: 'checkout_duration_seconds',
  help: 'Checkout duration, cart to confirmation',
  buckets: [0.1, 0.5, 1, 2],
  enableExemplars: true,
});

export const ordersCreated = new Counter({ name: 'orders_created_total', help: 'Orders placed' });

export const ordersFailed = new Counter({ name: 'orders_failed_total', help: 'Orders that failed to place' });

export const paymentAttempts = new Counter({
  name: 'payment_attempts_total',
  help: 'Payment capture attempts by outcome',
  labelNames: ['outcome'],
});

export const captureDuration = new Histogram({
  name: 'payment_capture_duration_seconds',
  help: 'PSP capture duration in seconds',
  buckets: [0.1, 0.25, 0.5, 1, 2.5, 5],
});

export const cartAbandon = new Counter({ name: 'cart_abandon_total', help: 'Carts that expired before payment' });

export const slowRequests = new Counter({
  name: 'http_slow_requests_total',
  help: 'Requests slower than the slow-request threshold',
  labelNames: ['route'],
});

export const feedLastImport = new Gauge({
  name: 'catalog_feed_last_import_timestamp_seconds',
  help: 'Unix time of the last completed supplier feed import',
});
