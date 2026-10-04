import { Module } from '@nestjs/common';
import { InvoiceListService } from './invoice-list.service';

@Module({
  providers: [InvoiceListService],
  exports: [InvoiceListService],
})
export class InvoicesModule {}
