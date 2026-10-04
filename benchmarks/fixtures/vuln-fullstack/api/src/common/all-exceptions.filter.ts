import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

// One error shape for every route, so the web client has a single place to read from.
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger('Exceptions');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const err = exception instanceof Error ? exception : new Error(String(exception));

    this.logger.error(`${req.method} ${req.path} -> ${status}: ${err.message}`, err.stack);

    res.status(status).json({
      statusCode: status,
      error: err.name,
      message: err.message,
      path: req.path,
      stack: err.stack,
      timestamp: new Date().toISOString(),
    });
  }
}
