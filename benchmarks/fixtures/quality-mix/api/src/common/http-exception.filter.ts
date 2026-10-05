import { ArgumentsHost, Catch, ExceptionFilter, HttpException, Logger } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { DomainError } from './errors';

// One error envelope for the whole API: { error: { code, message } }. Contract: docs/api/errors.md.
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('http');

  catch(exception: unknown, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : exception instanceof DomainError
          ? exception.status
          : 500;
    const code = exception instanceof DomainError ? exception.code : status === 500 ? 'internal' : 'http_error';
    if (status === 500) this.logger.error(exception);
    void reply.status(status).send({ error: { code, message: status === 500 ? 'Internal error' : (exception as Error).message } });
  }
}
