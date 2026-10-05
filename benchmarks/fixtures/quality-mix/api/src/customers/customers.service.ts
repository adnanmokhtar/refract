import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { NotFoundError } from '../common/errors';

@Injectable()
export class CustomersService {
  constructor(private readonly db: PrismaClient) {}

  async get(id: string) {
    const customer = await this.db.customer.findUnique({ where: { id } });
    if (!customer) throw new NotFoundError('customer', id);
    return customer;
  }
}
