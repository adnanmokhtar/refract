import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable, NotFoundException } from '@nestjs/common';
import { TxRunner } from '../common/tx-runner';
import { StockItem } from './stock-item.entity';
import { type StockRow, StockRepository } from './stock.repository';
import { StockReservationService } from './stock-reservation.service';

@Injectable()
export class StockService {
  constructor(
    private readonly em: EntityManager,
    private readonly repo: StockRepository,
    private readonly reservations: StockReservationService,
    private readonly tx: TxRunner,
  ) {}

  async list(page: number) {
    const items = await this.em.find(StockItem, {}, { orderBy: { sku: 'asc' }, limit: 50, offset: (page - 1) * 50 });
    return { data: items.map((i) => ({ sku: i.sku, description: i.description, quantity_available: i.quantityAvailable, quantity_reserved: i.quantityReserved, reorder_level: i.reorderLevel, unit: i.unit })) };
  }

  async show(sku: string, accountId: number) {
    const row = await this.repo.findBySku(accountId, sku);
    if (!row) {
      throw new NotFoundException();
    }
    const { pack_size: _packSize, ...item } = row;
    return { data: { ...item, packs_available: this.packsAvailable(row) } };
  }

  packsAvailable(row: StockRow): number {
    const free = row.quantity_available - row.quantity_reserved;
    return Math.max(Math.round(free / row.pack_size), 0);
  }

  async create(accountId: number, sku: string, description: string): Promise<void> {
    this.em.create(StockItem, { account: accountId, sku, description, quantityAvailable: 0, packSize: 1 });
    await this.em.flush();
  }

  async reserve(sku: string, quantity: number) {
    return this.tx.run(async (em) => {
      await this.reservations.reserve(em, sku, quantity);
      const item = await em.findOneOrFail(StockItem, { sku: sku.trim().toUpperCase() });
      return { data: { sku: item.sku, description: item.description, quantity_available: item.quantityAvailable, quantity_reserved: item.quantityReserved, reorder_level: item.reorderLevel, unit: item.unit } };
    });
  }
}
