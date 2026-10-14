import { RedisOptions } from 'ioredis';

/**
 * The notifications Redis: a managed Valkey cluster (DigitalOcean), reached over TLS on the managed port.
 * Only the push queue lives here, so a backlog of pushes never competes with the job Redis for memory.
 *
 * maxmemory-policy is noeviction on this cluster (set in the provider console when it was created).
 */
export function notifyConnection(): RedisOptions {
  const url = new URL(process.env.NOTIFY_REDIS_URL ?? 'rediss://localhost:25061');
  return { host: url.hostname, port: Number(url.port), tls: {}, maxRetriesPerRequest: null };
}
