import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface StockLineDto {
  productId: string;
  quantity: number;
}

export interface CreateTransferDto {
  fromWarehouseId: string;
  toWarehouseId: string;
  lines: StockLineDto[];
}

export interface CreateReturnDto {
  orderId: string;
  warehouseId: string;
  lines: StockLineDto[];
}

// Seller stock moves. Every movement is one row in the stock ledger; the ledger is keyed by
// idempotencyKey so a retried request never posts the same movement twice.
@Injectable()
export class StockTransfersService {
  constructor(private readonly prisma: PrismaService) {}

  // POST /api/inventory/transfers — dispatch stock from one of the seller's warehouses to another.
  async dispatch(sellerId: string, dto: CreateTransferDto) {
    if (!dto.lines.length) throw new BadRequestException('A transfer needs at least one line');
    const transfer = await this.prisma.stockTransfer.create({
      data: {
        sellerId,
        fromWarehouseId: dto.fromWarehouseId,
        toWarehouseId: dto.toWarehouseId,
        lines: { create: dto.lines.map((l) => ({ productId: l.productId, quantity: l.quantity })) },
      },
    });
    for (const line of dto.lines) {
      await this.post({
        idempotencyKey: `transfer:${transfer.id}:out:${line.productId}`,
        warehouseId: dto.fromWarehouseId,
        productId: line.productId,
        delta: -line.quantity,
      });
    }
    return transfer;
  }

  // POST /api/inventory/transfers/:id/receive — the destination books in what the transfer document lists.
  async receive(sellerId: string, transferId: string) {
    const transfer = await this.prisma.stockTransfer.findFirstOrThrow({
      where: { id: transferId, sellerId, receivedAt: null },
      include: { lines: true },
    });
    for (const docLine of transfer.lines) {
      await this.post({
        idempotencyKey: `transfer:${transfer.id}:in:${docLine.id}`,
        warehouseId: transfer.toWarehouseId,
        productId: docLine.productId,
        delta: docLine.quantity,
      });
    }
    return this.prisma.stockTransfer.update({ where: { id: transfer.id }, data: { receivedAt: new Date() } });
  }

  // POST /api/inventory/returns — buyer returns put back on the shelf. Lines for the same product
  // are summed first, so the document and the ledger hold one row per product.
  async restock(sellerId: string, dto: CreateReturnDto) {
    const perProduct = new Map<string, StockLineDto>();
    for (const l of dto.lines) {
      const seen = perProduct.get(l.productId);
      perProduct.set(l.productId, { productId: l.productId, quantity: (seen?.quantity ?? 0) + l.quantity });
    }
    const lines = [...perProduct.values()];
    const doc = await this.prisma.stockReturn.create({
      data: { sellerId, orderId: dto.orderId, warehouseId: dto.warehouseId, lines: { create: lines } },
    });
    for (const line of lines) {
      await this.post({
        idempotencyKey: `return:${doc.id}:${line.productId}`,
        warehouseId: dto.warehouseId,
        productId: line.productId,
        delta: line.quantity,
      });
    }
    return doc;
  }

  // A replayed key is a no-op: the existing ledger row is returned unchanged.
  private post(entry: { idempotencyKey: string; warehouseId: string; productId: string; delta: number }) {
    return this.prisma.stockLedgerEntry.upsert({
      where: { idempotencyKey: entry.idempotencyKey },
      create: entry,
      update: {},
    });
  }
}
