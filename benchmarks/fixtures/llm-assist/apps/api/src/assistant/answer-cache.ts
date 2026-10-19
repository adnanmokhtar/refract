import { Injectable } from '@nestjs/common';
import Redis from 'ioredis';
import { createHash } from 'node:crypto';

const TTL_SECONDS = 6 * 3600;

/** Caches KB answers so repeated questions skip the model. */
@Injectable()
export class AnswerCache {
  private readonly redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');

  private key(question: string): string {
    return `kb-answer:${createHash('sha256').update(question.trim().toLowerCase()).digest('hex')}`;
  }

  async get(question: string): Promise<string | null> {
    return this.redis.get(this.key(question));
  }

  async set(question: string, answer: string): Promise<void> {
    await this.redis.set(this.key(question), answer, 'EX', TTL_SECONDS);
  }
}
