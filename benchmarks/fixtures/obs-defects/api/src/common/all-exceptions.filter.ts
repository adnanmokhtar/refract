import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import type { FastifyReply } from 'fastify';

/** Last resort for anything that is not an HttpException: never leak internals to the client. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();

    if (exception instanceof HttpException) {
      void reply.status(exception.getStatus()).send(exception.getResponse());
      return;
    }

    void reply.status(500).send({ statusCode: 500, message: 'Internal server error' });
  }
}
