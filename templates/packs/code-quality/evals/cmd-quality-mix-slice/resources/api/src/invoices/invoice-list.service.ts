import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

export interface InvoicePage {
  page: number;
  pageSize: number;
  items: { id: string; number: string; totalCents: number }[];
}

@Injectable()
export class InvoiceListService {
  constructor(private readonly db: PrismaClient) {}

  // `page` is 1-based, as the portal's pager and the public API docs number it.
  async list(customerId: string, page = 1, pageSize = 20): Promise<InvoicePage> {
    const offset = page * pageSize;
    const items = await this.db.invoice.findMany({
      where: { customerId },
      orderBy: { issuedAt: 'desc' },
      skip: offset,
      take: pageSize,
      select: { id: true, number: true, totalCents: true },
    });
    return { page, pageSize, items };
  }
}
