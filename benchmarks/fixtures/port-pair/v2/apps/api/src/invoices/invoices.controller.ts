import { Controller, Get, HttpCode, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { Permissions } from '../common/permissions.decorator';
import { InvoicesService } from './invoices.service';

@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  @Permissions('invoices:view')
  list(@Query('page') page = '1', @Query('per_page') perPage = '25') {
    return this.invoices.list(Number(page), Math.min(Number(perPage), 100));
  }

  @Get(':id')
  @Permissions('invoices:view')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.invoices.get(id);
  }

  @Post(':id/issue')
  @Permissions('invoices:issue')
  @HttpCode(200)
  issue(@Param('id', ParseIntPipe) id: number) {
    return this.invoices.issue(id);
  }
}
