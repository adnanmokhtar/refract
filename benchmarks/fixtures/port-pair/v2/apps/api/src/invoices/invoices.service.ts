import { EntityManager, QueryOrder } from '@mikro-orm/postgresql';
import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { toMoneyString } from '../common/money';
import { TxRunner } from '../common/tx-runner';
import { toInvoiceDto } from './invoice.mapper';
import { invoiceTotals } from './invoice-totals';
import { Invoice } from './invoice.entity';

@Injectable()
export class InvoicesService {
  constructor(private readonly em: EntityManager, private readonly tx: TxRunner, @InjectQueue('invoices') private readonly queue: Queue) {}

  async list(page: number, perPage: number) {
    // V1: latest('issued_at') on MySQL, where NULLs sort last in DESC order.
    const items = await this.em.find(Invoice, {}, { orderBy: { issuedAt: QueryOrder.DESC_NULLS_LAST, id: QueryOrder.DESC }, limit: perPage, offset: (page - 1) * perPage, populate: ['lines'] });
    return { data: items.map(toInvoiceDto) };
  }

  async get(id: number) {
    return { data: toInvoiceDto(await this.em.findOneOrFail(Invoice, id, { populate: ['lines'] })) };
  }

  // Renders the stored invoice as PDF (dompdf template ported to the react-pdf renderer).
  async renderPdf(id: number): Promise<Buffer> {
    const invoice = await this.em.findOneOrFail(Invoice, id, { populate: ['lines'] });
    const { renderInvoicePdf } = await import('./invoice-pdf');
    return renderInvoicePdf(invoice);
  }

  async issue(id: number) {
    const invoice = await this.tx.run(async (em, onCommit) => {
      const inv = await em.findOneOrFail(Invoice, id, { populate: ['lines'] });
      const totals = invoiceTotals(inv.lines.getItems(), Number(inv.taxRate));
      const [{ seq }] = await em.getConnection().execute<{ seq: number }[]>(
        'update invoice_sequences set last_value = last_value + 1 where year = ? returning last_value as seq',
        [new Date().getFullYear()],
      );

      inv.number = `INV-${new Date().getFullYear()}-${String(seq).padStart(6, '0')}`;
      inv.subtotalAmount = toMoneyString(totals.subtotal);
      inv.taxAmount = toMoneyString(totals.tax);
      inv.totalAmount = toMoneyString(totals.total);
      inv.status = 'issued';
      inv.issuedAt = new Date();

      await this.queue.add('invoice-issued', { invoiceId: inv.id });
      return inv;
    });

    return { data: toInvoiceDto(invoice) };
  }
}
