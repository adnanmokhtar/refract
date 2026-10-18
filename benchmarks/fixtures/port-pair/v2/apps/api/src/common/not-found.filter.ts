import { ArgumentsHost, Catch, ExceptionFilter, NotFoundException } from '@nestjs/common';
import { NotFoundError } from '@mikro-orm/core';
import type { FastifyReply } from 'fastify';

// The V2 side of V1's Route::fallback and ModelNotFoundException rendering: an unknown route and
// a missing row both answer 404 `{ "message": "Not Found." }`, as V1 did.
@Catch(NotFoundException, NotFoundError)
export class NotFoundFilter implements ExceptionFilter {
  catch(_exception: NotFoundException | NotFoundError, host: ArgumentsHost): void {
    const reply = host.switchToHttp().getResponse<FastifyReply>();
    void reply.status(404).send({ message: 'Not Found.' });
  }
}
