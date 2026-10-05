// Domain errors carry the HTTP status the global filter answers with.
export abstract class DomainError extends Error {
  abstract readonly status: number;
  abstract readonly code: string;
}

export class NotFoundError extends DomainError {
  readonly status = 404;
  readonly code = 'not_found';
  constructor(what: string, id: string) {
    super(`${what} ${id} not found`);
  }
}

export class ConflictError extends DomainError {
  readonly status = 409;
  readonly code = 'conflict';
}

export class PaymentDeclinedError extends DomainError {
  readonly status = 402;
  readonly code = 'payment_declined';
}

// Thrown by request parsing and the plan-change rules; the API contract answers it with 422.
export class ValidationError extends Error {
  readonly code = 'validation_failed';
  constructor(message: string, readonly fields: string[] = []) {
    super(message);
  }
}
