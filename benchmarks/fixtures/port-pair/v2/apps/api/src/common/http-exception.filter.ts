import { ArgumentsHost, Catch, ExceptionFilter, HttpException } from '@nestjs/common';
import type { FastifyReply } from 'fastify';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    const body = exception.getResponse();
    const payload = typeof body === 'string' ? { message: body } : body;

    void reply.status(exception.getStatus()).send(payload);
  }
}
