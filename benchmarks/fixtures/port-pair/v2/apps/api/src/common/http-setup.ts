import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import { HttpExceptionFilter } from './http-exception.filter';
import { NormalizeInputPipe } from './normalize-input.pipe';
import { NotFoundFilter } from './not-found.filter';

export { registerCsrf } from './csrf';

export function globalFilters() {
  return [new HttpExceptionFilter(), new NotFoundFilter()];
}

// V2's answer to Laravel's global TrimStrings + ConvertEmptyStringsToNull middleware.
export function registerInputNormalization(app: NestFastifyApplication): void {
  app.useGlobalPipes(new NormalizeInputPipe({ trim: true, emptyToNull: true, except: ['password', 'password_confirmation', 'current_password'] }));
}
