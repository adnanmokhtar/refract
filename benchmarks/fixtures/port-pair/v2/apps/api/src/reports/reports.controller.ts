import { Controller, Get, Query } from '@nestjs/common';
import { Permissions } from '../common/permissions.decorator';
import { ReportsService } from './reports.service';

@Controller('reports')
@Permissions('reports:view')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('sales')
  sales(@Query('from') from: string, @Query('to') to: string) {
    return this.reports.sales(from, to);
  }

  @Get('sla')
  sla() {
    return this.reports.sla();
  }
}
