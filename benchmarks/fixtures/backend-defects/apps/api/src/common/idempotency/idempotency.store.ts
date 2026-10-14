import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';

export interface StoredResponse {
  status: number;
  body: unknown;
}

export interface IdempotencyRecord {
  state: 'in_flight' | 'done';
  response: StoredResponse;
}

const TTL_SECONDS = 24 * 60 * 60;

/** Shared across replicas: one Redis key per Idempotency-Key, 24 h. */
@Injectable()
export class IdempotencyStore {
  constructor(@Inject('REDIS') private readonly redis: Redis) {}

  async get(key: string): Promise<IdempotencyRecord | undefined> {
    const raw = await this.redis.get(key);
    return raw ? (JSON.parse(raw) as IdempotencyRecord) : undefined;
  }

  async begin(key: string): Promise<boolean> {
    const rec: IdempotencyRecord = { state: 'in_flight', response: { status: 0, body: null } };
    return (await this.redis.set(key, JSON.stringify(rec), 'EX', TTL_SECONDS, 'NX')) === 'OK';
  }

  async finish(key: string, response: StoredResponse): Promise<void> {
    await this.redis.set(key, JSON.stringify({ state: 'done', response }), 'EX', TTL_SECONDS);
  }
}
