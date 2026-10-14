import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import pRetry from 'p-retry';
import { AddressBookEntry } from './address-book-entry.entity';

/**
 * Merchants import address books from CSV. Concurrent imports for one merchant collide on the
 * (merchant_id, label) unique index now and then; retrying the flush resolves it.
 */
@Injectable()
export class ImportAddressBook {
  constructor(private readonly em: EntityManager) {}

  async execute(merchantId: string, rows: Array<{ label: string; line1: string; city: string; postcode: string }>): Promise<void> {
    for (const row of rows) {
      this.em.persist(new AddressBookEntry(merchantId, row.label, row.line1, row.city, row.postcode));
    }
    await pRetry(() => this.em.flush(), { retries: 3, randomize: true, minTimeout: 200 });
  }
}
