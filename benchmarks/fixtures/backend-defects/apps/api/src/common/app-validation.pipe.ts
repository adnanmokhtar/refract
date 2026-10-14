import { Injectable, ValidationPipe } from '@nestjs/common';

/**
 * The one validation pipe of the public API, registered as APP_PIPE in app.module.ts.
 * Error messages are rewritten into the envelope by GlobalExceptionFilter.
 */
@Injectable()
export class AppValidationPipe extends ValidationPipe {
  constructor() {
    super({ transform: true, whitelist: true, stopAtFirstError: false });
  }
}
