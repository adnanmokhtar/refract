import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { Logger } from 'nestjs-pino';

/** Every HttpException thrown by a controller or service: validation, not-found, payment-declined, conflicts. */
@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  constructor(private readonly logger: Logger) {}

  catch(exception: HttpException, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    const request = host.switchToHttp().getRequest<FastifyRequest>();
    const status = exception.getStatus();

    this.logger.error({ err: exception, cause: exception.cause, status, route: request.routeOptions.url }, 'request failed');

    void reply.status(status).send({ statusCode: status, message: exception.message });
  }
}
