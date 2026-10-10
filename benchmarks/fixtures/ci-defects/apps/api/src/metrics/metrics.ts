import { Counter, Histogram, register } from 'prom-client';

export const httpRequests = new Counter({
  name: 'http_requests_total',
  help: 'HTTP requests by route and status',
  labelNames: ['route', 'method', 'status'],
  registers: [register],
});

export const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['route', 'method'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [register],
});
