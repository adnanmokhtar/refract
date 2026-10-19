import { ConflictException, Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Invoice, InvoiceStatus } from './invoice.entity';

@Injectable()
export class InvoiceDraftsService {
  constructor(private readonly em: EntityManager) {}

  /** Drafts are edited freely until they are issued; the status is part of the WHERE. */
  async editDraft(id: string, lines: unknown[], netMinor: number, taxMinor: number): Promise<void> {
    const changed = await this.em.nativeUpdate(Invoice, { id, status: InvoiceStatus.Draft }, { lines, netMinor, taxMinor, totalMinor: netMinor + taxMinor });
    if (changed !== 1) throw new ConflictException('only a draft invoice can be edited');
  }
}
