import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';

type OnCommit = (fn: () => Promise<unknown>) => void;

// The V2 side of Laravel's `->afterCommit()`: callbacks registered with onCommit run only after
// the transaction commits, and never when it rolls back.
@Injectable()
export class TxRunner {
  constructor(private readonly em: EntityManager) {}

  async run<T>(work: (em: EntityManager, onCommit: OnCommit) => Promise<T>): Promise<T> {
    const pending: Array<() => Promise<unknown>> = [];
    const result = await this.em.transactional((em) => work(em as EntityManager, (fn) => pending.push(fn)));
    for (const fn of pending) {
      await fn();
    }
    return result;
  }
}
