import { Module } from '@nestjs/common';
import { CustomerLookupService } from './customer-lookup.service';

@Module({
  providers: [CustomerLookupService],
  exports: [CustomerLookupService],
})
export class CustomersModule {}
