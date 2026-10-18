import { type ArgumentsHost, Catch, type ExceptionFilter, HttpException, HttpStatus } from '@nestjs/common';
import type { FastifyReply, FastifyRequest } from 'fastify';

// ADR-0004: every error leaves as application/problem+json.
@Catch()
export class ProblemDetailsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const reply = ctx.getResponse<FastifyReply>();
    const request = ctx.getRequest<FastifyRequest>();
    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const title = exception instanceof HttpException ? exception.message : 'Internal Server Error';
    void reply
      .status(status)
      .header('content-type', 'application/problem+json')
      .send({ type: 'about:blank', title, status, instance: request.url });
  }
}
