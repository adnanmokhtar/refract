import { EntityManager } from '@mikro-orm/postgresql';

/** Right-to-erasure requests: removes the subject from the operational tables. */
export class EraseCustomerHandler {
  constructor(private readonly em: EntityManager) {}

  async erase(customerId: string, email: string): Promise<void> {
    await this.em.transactional(async (tx) => {
      const conn = tx.getConnection();
      await conn.execute(`delete from sessions where customer_id = ?`, [customerId]);
      await conn.execute(`update orders set customer_email = null, shipping_address = null where customer_id = ?`, [customerId]);
      await conn.execute(`delete from customers where id = ?`, [customerId]);
    });
  }
}
