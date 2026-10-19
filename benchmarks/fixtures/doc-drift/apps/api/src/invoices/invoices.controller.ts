import { Controller, Get, Header, Param } from '@nestjs/common';

import { InvoicesService } from './invoices.service';

@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoicesService: InvoicesService) {}

  @Get(':id')
  get(@Param('id') id: string) {
    return this.invoicesService.get(id);
  }

  @Get(':id/pdf')
  @Header('Content-Type', 'application/pdf')
  pdf(@Param('id') id: string) {
    return this.invoicesService.pdf(id);
  }
}
