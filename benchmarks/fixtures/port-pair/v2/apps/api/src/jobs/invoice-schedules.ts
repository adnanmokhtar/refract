import { EntityManager } from '@mikro-orm/postgresql';
import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InvoicesService } from '../invoices/invoices.service';
import { Invoice } from '../invoices/invoice.entity';

// V1: Schedule::command('invoices:issue-nightly')->dailyAt('01:30')->timezone('Asia/Riyadh')->onOneServer().
// The API runs as one scheduler replica (deploy/k8s/api-deployment.yaml SCHEDULER_ENABLED).
@Injectable()
export class InvoiceSchedules {
  constructor(private readonly em: EntityManager, private readonly invoices: InvoicesService) {}

  @Cron('0 30 1 * * *', { name: 'invoices-issue-nightly', timeZone: 'Asia/Riyadh' })
  async issueNightly(): Promise<void> {
    const drafts = await this.em.find(Invoice, { status: 'draft', orderId: { $ne: null } }, { filters: false, fields: ['id'] });
    for (const draft of drafts) {
      await this.invoices.issue(draft.id);
    }
  }
}
