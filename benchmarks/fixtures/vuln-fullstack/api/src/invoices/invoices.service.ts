import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class InvoicesService {
  constructor(private readonly prisma: PrismaService) {}

  listFor(userId: string) {
    return this.prisma.invoice.findMany({
      where: { OR: [{ buyerId: userId }, { sellerId: userId }] },
      orderBy: { issuedAt: 'desc' },
      take: 100,
    });
  }

  async findById(id: string) {
    const invoice = await this.prisma.invoice.findUnique({
      where: { id },
      include: { order: { include: { items: true } } },
    });
    if (!invoice) throw new NotFoundException();
    return invoice;
  }
}
