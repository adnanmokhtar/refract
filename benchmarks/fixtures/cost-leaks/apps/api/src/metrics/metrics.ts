import { Counter, Histogram, Registry, collectDefaultMetrics } from 'prom-client';

export const registry = new Registry();
collectDefaultMetrics({ register: registry });

export const httpDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

// Tokens the model gateway bills, per tenant and feature.
export const llmTokens = new Counter({
  name: 'llm_gateway_tokens_total',
  help: 'Tokens billed by the model gateway',
  labelNames: ['tenant', 'feature', 'user_id', 'direction'],
  registers: [registry],
});

export const carrierCalls = new Counter({
  name: 'carrier_api_calls_total',
  help: 'Billed calls to the carrier API',
  labelNames: ['endpoint', 'outcome'],
  registers: [registry],
});

export const geocoderLookups = new Counter({
  name: 'geocoder_lookups_total',
  help: 'Billed geocoder lookups',
  labelNames: ['tenant', 'outcome'],
  registers: [registry],
});
