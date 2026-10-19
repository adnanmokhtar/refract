import { AsyncLocalStorage } from 'node:async_hooks';
import { Injectable, NestMiddleware } from '@nestjs/common';
import { FastifyReply, FastifyRequest } from 'fastify';

export interface TenantContext {
  tenantId: string;
}

const storage = new AsyncLocalStorage<TenantContext>();

export function currentTenant(): string {
  const ctx = storage.getStore();
  if (!ctx) {
    throw new Error('no tenant in scope');
  }
  return ctx.tenantId;
}

@Injectable()
export class TenantFilter implements NestMiddleware {
  use(req: FastifyRequest, _reply: FastifyReply, next: () => void): void {
    const tenantId = String(req.headers['x-tenant-id'] ?? '');
    storage.run({ tenantId }, next);
  }
}

export function withTenant<T>(tenantId: string, job: () => Promise<T>): Promise<T> {
  return storage.run({ tenantId }, job);
}
