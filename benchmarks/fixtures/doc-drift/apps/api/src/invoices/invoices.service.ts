import { Injectable, NotFoundException } from '@nestjs/common';

import { InvoicePdfStore } from './invoice-pdf.store';

@Injectable()
export class InvoicesService {
  constructor(private readonly pdfs: InvoicePdfStore) {}

  async get(id: string) {
    throw new NotFoundException(`invoice ${id} not found`);
  }

  pdf(id: string) {
    return this.pdfs.read(id);
  }
}
