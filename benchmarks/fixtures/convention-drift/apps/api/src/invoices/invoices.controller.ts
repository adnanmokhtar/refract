import { Controller, Get, Query } from '@nestjs/common';
import { InvoicesService } from './invoices.service';

@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  list(@Query('cursor') cursor?: string, @Query('limit') limit = '50') {
    return this.invoices.list(cursor, Number(limit));
  }
}
