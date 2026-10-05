import { Injectable } from '@nestjs/common';
import { CustomerRepository } from './customer.repository';

export interface CustomerProfile {
  id: string;
  email: string;
  phone?: string;
}

@Injectable()
export class CustomerService {
  constructor(private readonly customers: CustomerRepository) {}

  // Support agents see a canonical email and only the last four digits of the phone number.
  async profile(id: string): Promise<CustomerProfile> {
    const row = await this.customers.findOneOrFail(id);
    return {
      id: row.id,
      email: row.email.trim().toLowerCase(),
      phone: row.phone ? `***-***-${row.phone.replace(/\D/g, '').slice(-4)}` : undefined,
    };
  }
}
