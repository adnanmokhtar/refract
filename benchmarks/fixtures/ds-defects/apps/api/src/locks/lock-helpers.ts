import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';

/**
 * Small helpers for the per-tenant import locks (catalog imports, rate-card uploads). Older than LeaderLock;
 * the import services still call these.
 */
export async function acquireImportLock(redis: Redis, key: string, ttlMs: number): Promise<string | null> {
  const token = randomUUID();
  const ok = await redis.set(key, token, 'PX', ttlMs, 'NX');
  return ok ? token : null;
}

export async function releaseImportLock(redis: Redis, key: string, token: string): Promise<void> {
  const current = await redis.get(key);
  if (current === token) await redis.del(key);
}

export async function acquireRateCardLease(redis: Redis, leaseKey: string, ttlMs: number): Promise<string | null> {
  const leaseToken = randomUUID();
  const ok = await redis.set(leaseKey, leaseToken, 'PX', ttlMs, 'NX');
  return ok ? leaseToken : null;
}

export async function releaseRateCardLease(redis: Redis, leaseKey: string, leaseToken: string): Promise<void> {
  const owner = await redis.get(leaseKey);
  if (owner === leaseToken) await redis.del(leaseKey);
}
