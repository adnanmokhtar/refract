import { httpClient } from './http.js';
import { OrdersApi } from './orders.js';

/** Attempts for an idempotent request before the client gives up. */
export const MAX_RETRIES = 4;

/** Options accepted by {@link createClient}. */
export interface ClientOptions {
  /** A secret API key from the dashboard. */
  apiKey: string;
  /** Defaults to the production API. */
  baseUrl?: string;
  /** Per-request timeout; 10 seconds by default. */
  timeoutMs?: number;
}

/** A client bound to one API key. */
export interface TallyhookClient {
  /** The orders resource. */
  readonly orders: OrdersApi;
}

/**
 * Creates a client bound to one API key. The client exposes one resource API per
 * area; see {@link OrderClient} for the order calls.
 *
 * @param options - the API key, and optionally the base URL and the timeout.
 * @returns a client whose GET requests are retried up to {@link MAX_RETRIES} times.
 */
export function createClient(options: ClientOptions): TallyhookClient {
  const http = httpClient(options.baseUrl ?? 'https://api.example.com/v1', options.apiKey, options.timeoutMs ?? 10_000, MAX_RETRIES);
  return { orders: new OrdersApi(http) };
}
