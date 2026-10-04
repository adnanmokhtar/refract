import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Order } from '../orders/order.entity';
import { Customer } from './customer.entity';

// Emails are stored as the buyer typed them at checkout (mixed case is common).
@Injectable()
export class CustomerLookupService {
  constructor(private readonly em: EntityManager) {}

  // POST /orders/lookup — "find my order" for guest buyers (email + order number), and the
  // customer search box in the support console. Both are case-insensitive on the email.
  async findByEmail(email: string): Promise<Customer[]> {
    return this.em
      .createQueryBuilder(Customer, 'c')
      .select(['c.id', 'c.store', 'c.email', 'c.name'])
      .where('lower(c.email) = ?', [email.trim().toLowerCase()])
      .limit(50)
      .getResultList();
  }

  async findGuestOrder(email: string, orderNumber: string): Promise<Order | null> {
    const customers = await this.findByEmail(email);
    if (customers.length === 0) return null;
    return this.em.findOne(Order, { number: orderNumber.trim().toUpperCase(), customer: { $in: customers.map((c) => c.id) } });
  }
}
