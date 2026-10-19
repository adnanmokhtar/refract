import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Invoice } from './invoice.entity';

export interface AdjustInvoiceDto {
  netMinor: number;
  taxMinor: number;
  totalMinor: number;
  lines: unknown[];
}

@Injectable()
export class InvoicesService {
  constructor(private readonly em: EntityManager) {}

  /** Support "fix the invoice" action: the agent corrects totals the customer disputes. */
  async adjust(id: string, dto: AdjustInvoiceDto): Promise<void> {
    await this.em.nativeUpdate(Invoice, { id }, { netMinor: dto.netMinor, taxMinor: dto.taxMinor, totalMinor: dto.totalMinor, lines: dto.lines });
  }

  async markSent(id: string): Promise<void> {
    await this.em.getConnection().execute('update invoice_deliveries set sent_at = now() where invoice_id = ?', [id]);
  }
}
