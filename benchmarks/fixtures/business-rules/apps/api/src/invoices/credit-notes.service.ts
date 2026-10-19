import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { CreditNote } from './credit-note.entity';

export interface CreditNoteDto {
  originalInvoiceId?: string;
  amountMinor: number;
  reason: string;
}

@Injectable()
export class CreditNotesService {
  constructor(private readonly em: EntityManager) {}

  async create(dto: CreditNoteDto): Promise<CreditNote> {
    const note = this.em.create(CreditNote, {
      originalInvoiceId: dto.originalInvoiceId ?? null,
      amountMinor: dto.amountMinor,
      reason: dto.reason,
      issuedAt: new Date(),
    });
    await this.em.persistAndFlush(note);
    return note;
  }
}
