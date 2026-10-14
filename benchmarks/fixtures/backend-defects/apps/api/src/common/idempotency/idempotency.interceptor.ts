import {
  CallHandler,
  ConflictException,
  ExecutionContext,
  Injectable,
  NestInterceptor,
  SetMetadata,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable, from, of, switchMap, tap } from 'rxjs';
import { IdempotencyStore, StoredResponse } from './idempotency.store';

export const IDEMPOTENT = 'idempotent';
export const Idempotent = () => SetMetadata(IDEMPOTENT, true);

/**
 * Honours the Idempotency-Key header on routes marked @Idempotent(): the first response is
 * stored for 24 h and replayed for the same key.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(private readonly reflector: Reflector, private readonly store: IdempotencyStore) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (!this.reflector.get<boolean>(IDEMPOTENT, ctx.getHandler())) return next.handle();
    const req = ctx.switchToHttp().getRequest<{ headers: Record<string, string>; body: unknown }>();
    const key = req.headers['idempotency-key'];
    if (!key) return next.handle();

    const storeKey = `idem:${key}`;
    return from(this.store.get(storeKey)).pipe(
      switchMap((rec) => {
        if (rec && rec.state === 'done') {
          return of(rec.response.body);
        }
        if (rec && rec.state === 'in_flight') {
          throw new ConflictException({ statusCode: 409, message: 'Request with this key is in progress' });
        }
        return from(this.store.begin(storeKey)).pipe(
          switchMap(() => next.handle()),
          tap((body) => void this.store.finish(storeKey, { status: 200, body } as StoredResponse)),
        );
      }),
    );
  }
}
