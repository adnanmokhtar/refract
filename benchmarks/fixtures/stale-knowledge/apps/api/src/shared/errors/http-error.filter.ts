import { ArgumentsHost, Catch, ExceptionFilter } from '@nestjs/common';
import { FastifyReply } from 'fastify';
import { DomainError } from './domain-error';

@Catch(DomainError)
export class HttpErrorFilter implements ExceptionFilter {
  catch(error: DomainError, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    void reply.status(error.status).type('application/problem+json').send({
      type: `https://errors.orderly.example.com/${error.code}`,
      title: error.message,
      status: error.status,
    });
  }
}
