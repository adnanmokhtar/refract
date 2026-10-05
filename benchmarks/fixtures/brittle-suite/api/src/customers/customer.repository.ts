import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Customer } from './customer.entity';

@Injectable()
export class CustomerRepository {
  constructor(private readonly em: EntityManager) {}

  findOneOrFail(id: string): Promise<Customer> {
    return this.em.findOneOrFail(Customer, { id });
  }

  async create(tenantId: string, email: string): Promise<Customer> {
    const customer = this.em.create(Customer, { tenantId, email });
    await this.em.flush();
    return customer;
  }
}
