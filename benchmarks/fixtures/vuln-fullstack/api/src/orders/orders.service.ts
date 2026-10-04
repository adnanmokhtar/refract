import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const PAGE_SIZE = 50;
const DIRECTIONS = ['ASC', 'DESC'];

export interface SellerOrderRow {
  id: string;
  number: number;
  status: string;
  total_cents: number;
  created_at: Date;
  buyer_email: string;
}

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  // Seller dashboard order table; every column header is sortable.
  async listForSeller(sellerId: string, sort = 'created_at', dir = 'DESC', page = 1) {
    const direction = DIRECTIONS.includes(dir.toUpperCase()) ? dir.toUpperCase() : 'DESC';
    const offset = (Math.max(page, 1) - 1) * PAGE_SIZE;

    return this.prisma.$queryRawUnsafe<SellerOrderRow[]>(
      `SELECT o.id, o.number, o.status, o.total_cents, o.created_at, b.email AS buyer_email
         FROM orders o
         JOIN users b ON b.id = o.buyer_id
        WHERE o.seller_id = $1::uuid
        ORDER BY ${sort} ${direction}
        LIMIT ${PAGE_SIZE} OFFSET $2`,
      sellerId,
      offset,
    );
  }

  listForBuyer(buyerId: string) {
    return this.prisma.order.findMany({
      where: { buyerId },
      orderBy: { createdAt: 'desc' },
      take: PAGE_SIZE,
      include: { items: true },
    });
  }

  async markShipped(orderId: string, sellerId: string) {
    const updated = await this.prisma.order.updateMany({
      where: { id: orderId, sellerId, status: 'PAID' },
      data: { status: 'SHIPPED' },
    });
    if (updated.count === 0) throw new NotFoundException();
    return { ok: true };
  }
}
