import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { RequestContext } from '@mikro-orm/core';

/** Runs a unit of work in one transaction; every repository and the outbox port use the context `em` inside it. */
@Injectable()
export class TxRunner {
  constructor(private readonly em: EntityManager) {}

  run<T>(work: () => Promise<T>): Promise<T> {
    return this.em.transactional(async (tx) => RequestContext.create(tx, work));
  }
}
