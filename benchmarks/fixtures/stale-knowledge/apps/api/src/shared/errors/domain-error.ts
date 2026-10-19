export class DomainError extends Error {
  constructor(readonly code: string, message: string, readonly status = 422) {
    super(message);
  }
}

export class NotFoundDomainError extends DomainError {
  constructor(entity: string, id: string) {
    super('not_found', `${entity} ${id} was not found`, 404);
  }
}
