import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import {
  CheckConstraintViolationException,
  ForeignKeyConstraintViolationException,
  NotNullConstraintViolationException,
  OptimisticLockError,
  UniqueConstraintViolationException,
} from '@mikro-orm/core';
import { DomainError, NotFoundError } from '../errors';
import { UpstreamError } from '../http-client';

type Mapped = { status: number; code: string };

export function statusFor(e: unknown): Mapped {
  if (e instanceof NotFoundError) return { status: 404, code: 'NOT_FOUND' };
  if (e instanceof DomainError) return { status: e.status, code: e.code };
  if (e instanceof UniqueConstraintViolationException) return { status: 409, code: 'DUPLICATE' };
  if (e instanceof ForeignKeyConstraintViolationException) return { status: 409, code: 'REFERENCE_MISSING' };
  if (e instanceof NotNullConstraintViolationException) return { status: 400, code: 'FIELD_REQUIRED' };
  if (e instanceof CheckConstraintViolationException) return { status: 400, code: 'CONSTRAINT' };
  if (e instanceof OptimisticLockError) return { status: 412, code: 'STALE_VERSION' };
  if (e instanceof UpstreamError) return { status: 502, code: `UPSTREAM_${e.provider.toUpperCase()}` };
  return { status: HttpStatus.INTERNAL_SERVER_ERROR, code: 'INTERNAL' };
}

function codeForStatus(status: number): string {
  return HttpStatus[status] ?? 'HTTP_ERROR';
}

/** Global filter (APP_FILTER). Every error leaves as {"error": {code, message, details}}. */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        reply.status(status).send({ error: { code: codeForStatus(status), message: res } });
        return;
      }
      if ('statusCode' in res) {
        const r = res as { message: string | string[] };
        const details = Array.isArray(r.message) ? r.message : [];
        reply.status(status).send({ error: { code: codeForStatus(status), message: String(r.message), details } });
        return;
      }
      reply.status(status).send(res);
      return;
    }

    // Fastify's own refusals (body too large, bad content type) carry a 4xx statusCode.
    const fst = (exception as { statusCode?: number }).statusCode;
    if (typeof fst === 'number' && fst >= 400 && fst < 500) {
      reply.status(fst).send({ error: { code: codeForStatus(fst), message: (exception as Error).message } });
      return;
    }

    const { status, code } = statusFor(exception);
    if (status === HttpStatus.INTERNAL_SERVER_ERROR) {
      reply.status(500).send({ error: { code, message: 'Internal error' } });
      return;
    }
    reply.status(status).send({ error: { code, message: (exception as Error).message } });
  }
}
