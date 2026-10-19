import { Module } from '@nestjs/common';

import { InvoicePdfStore } from './invoice-pdf.store';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';

@Module({ controllers: [InvoicesController], providers: [InvoicesService, InvoicePdfStore] })
export class InvoicesModule {}
