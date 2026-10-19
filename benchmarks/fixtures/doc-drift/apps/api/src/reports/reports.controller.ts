import { Controller, Get, Query } from '@nestjs/common';

import { ReportsService } from './reports.service';

@Controller('reports')
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('monthly')
  monthly(@Query('month') month: string, @Query('format') format: 'json' | 'csv' = 'json') {
    return this.reportsService.monthly(month, format);
  }
}
