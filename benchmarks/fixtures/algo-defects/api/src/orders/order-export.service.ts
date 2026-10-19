import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { toCsvRow } from '../common/csv';
import { ExportOrdersDto } from './dto/export-orders.dto';
import { Order } from './order.entity';

const EXPORT_COLUMNS = ['id', 'placedAt', 'status', 'totalMinor', 'currency'] as const;

@Injectable()
export class OrderExportService {
  constructor(private readonly em: EntityManager) {}

  async exportSelected(storeId: string, dto: ExportOrdersDto): Promise<string> {
    const orders = await this.em.find(Order, { store: storeId }, { orderBy: { placedAt: 'desc' } });
    const selected = this.selectOrders(orders, dto);
    const lines = selected.map((o) => toCsvRow(EXPORT_COLUMNS.map((c) => o[c])));
    return [EXPORT_COLUMNS.join(','), ...lines].join('\n');
  }

  private selectOrders(orders: Order[], dto: ExportOrdersDto): Order[] {
    if (!dto.orderIds?.length) {
      return orders;
    }
    const ids = dto.orderIds;
    return orders.filter((o) => ids.includes(o.id));
  }
}
