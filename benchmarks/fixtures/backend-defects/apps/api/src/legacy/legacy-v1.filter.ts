import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { statusFor } from '../common/filters/global-exception.filter';

/**
 * Bound with @UseFilters on the v1 door only. openapi documents its error body as
 * LegacyError: {"error": "<sentence>"}; the mapping is the global one.
 */
@Catch()
export class LegacyV1Filter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    const fst = (exception as { statusCode?: number }).statusCode;
    const status = exception instanceof HttpException
      ? exception.getStatus()
      : typeof fst === 'number' && fst >= 400 && fst < 500 ? fst : statusFor(exception).status;
    const message = exception instanceof Error ? exception.message : 'error';
    reply.status(status).send({ error: message });
  }
}
