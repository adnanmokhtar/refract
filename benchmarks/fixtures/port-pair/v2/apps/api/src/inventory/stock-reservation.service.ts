import { EntityManager, LockMode } from '@mikro-orm/postgresql';
import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { StockItem } from './stock-item.entity';

@Injectable()
export class StockReservationService {
  constructor(private readonly em: EntityManager) {}

  // Called inside the caller's transaction (OrderPlacementService.place, StockService.reserve).
  async reserve(em: EntityManager, sku: string, quantity: number) {
    const item = await em.findOneOrFail(StockItem, { sku: sku.trim().toUpperCase() });

    if (item.quantityAvailable - item.quantityReserved < quantity) {
      throw new UnprocessableEntityException({ message: `Not enough stock for ${sku}.`, errors: { lines: [`Not enough stock for ${sku}.`] } });
    }

    item.quantityReserved += quantity;
    await em.flush();
    return { sku: item.sku, quantity_reserved: item.quantityReserved };
  }

  // Gives reserved units back (order cancelled before packing).
  async release(em: EntityManager, sku: string, quantity: number) {
    const item = await em.findOneOrFail(StockItem, { sku: sku.trim().toUpperCase() }, { lockMode: LockMode.PESSIMISTIC_WRITE });
    item.quantityReserved = Math.max(item.quantityReserved - quantity, 0);
    await em.flush();
  }

  // Port of V1 ReleaseStaleReservations: drafts idle for 30 minutes give their stock back.
  async releaseStale(): Promise<number> {
    return this.em.getConnection().execute(`
      update stock_items si set quantity_reserved = greatest(si.quantity_reserved - stale.qty, 0)
      from (
        select ol.sku, o.account_id, sum(ol.quantity) as qty
        from order_lines ol join orders o on o.id = ol.order_id
        where o.status = 'draft' and o.updated_at < now() - interval '30 minutes' and o.deleted_at is null
        group by ol.sku, o.account_id
      ) stale
      where stale.sku = si.sku and stale.account_id = si.account_id`);
  }
}
