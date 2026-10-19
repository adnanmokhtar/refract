import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Customer } from './customer.entity';
import { Invoice } from '../invoices/invoice.entity';
import { Order } from '../orders/order.entity';

/** "Delete my account" from the customer's settings page. */
@Injectable()
export class AccountDeletionService {
  constructor(private readonly em: EntityManager) {}

  async deleteAccount(customerId: string): Promise<void> {
    await this.em.transactional(async (em) => {
      await em.nativeDelete(Invoice, { order: { customerId } });
      await em.nativeDelete(Order, { customerId });
      await em.nativeDelete(Customer, { id: customerId });
    });
  }
}
