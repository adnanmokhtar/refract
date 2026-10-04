import { Logger, LoggerNamespace, LogContext } from '@mikro-orm/core';

// A MikroORM logger that counts SQL statements. Pass `loggerFactory: () => counter` and
// `debug: ['query']` in the test module's ORM config, reset before each request, and assert.
export class QueryCounter implements Logger {
  count = 0;
  statements: string[] = [];

  log(namespace: LoggerNamespace, message: string, _context?: LogContext): void {
    if (namespace !== 'query') return;
    this.count++;
    this.statements.push(message);
  }

  error(): void {}
  warn(): void {}
  logQuery(context: { query: string } & LogContext): void {
    this.log('query', context.query, context);
  }
  setDebugMode(): void {}
  isEnabled(namespace: LoggerNamespace): boolean {
    return namespace === 'query';
  }

  reset(): void {
    this.count = 0;
    this.statements = [];
  }
}
