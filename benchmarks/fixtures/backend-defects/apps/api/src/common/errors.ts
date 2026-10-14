// Domain errors of the application layer. Every use case throws one of these; the global
// filter maps each to its status and machine code.
export abstract class DomainError extends Error {
  abstract readonly status: number;
  abstract readonly code: string;
}

export class NotFoundError extends DomainError {
  readonly status = 404;
  readonly code = 'NOT_FOUND';
  constructor(readonly entity: string, readonly id: string) {
    super(`${entity} ${id} not found`);
    this.name = 'NotFoundError';
  }
}

export class ConflictError extends DomainError {
  readonly status = 409;
  readonly code = 'CONFLICT';
}

export class IllegalStateError extends DomainError {
  readonly status = 409;
  readonly code = 'ILLEGAL_STATE';
}

export class PaymentDeclinedError extends DomainError {
  readonly status = 402;
  readonly code = 'PAYMENT_DECLINED';
}
