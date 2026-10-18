import { HttpException } from '@nestjs/common';

// A domain rule refused the request. Renders as `{ message, code? }` with the given status, the
// shape V1's exception handler rendered (bootstrap/app.php withExceptions).
export class DomainError extends HttpException {
  constructor(status: number, message: string, code?: string) {
    super(code ? { message, code } : { message }, status);
  }
}
