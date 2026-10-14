// Errors raised by the ledger posting engine.
export class LedgerError extends Error {
  constructor(message: string, readonly account: string) {
    super(message);
    this.name = 'LedgerError';
  }
}

export class InsufficientFundsError extends LedgerError {}

export class AccountFrozenError extends LedgerError {}

export class CurrencyMismatchError extends LedgerError {}
