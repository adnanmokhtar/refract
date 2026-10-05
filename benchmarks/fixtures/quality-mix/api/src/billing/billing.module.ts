import { Module } from '@nestjs/common';
import { InvoicePaidListener } from './invoice-paid.listener';
import { BillingService } from './billing.service';
import { ChargesService } from './charges.service';
import { ProviderClient } from './provider.client';
import { InvoicePdfController } from './invoice-pdf.controller';

@Module({
  controllers: [InvoicePdfController],
  providers: [InvoicePaidListener, BillingService, ChargesService, ProviderClient],
  exports: [BillingService, ChargesService],
})
export class BillingModule {}
