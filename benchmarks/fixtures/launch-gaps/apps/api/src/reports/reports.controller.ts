import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';
import { ReportsService } from './reports.service';

@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @RequireModule('reports')
  @Get()
  overview(@Query('range') range = '30d') {
    return this.reports.overview(range);
  }

  /** Cohort retention by first-order month. An advanced-reports extension feature. */
  @RequireModule('advanced-reports')
  @Get('cohorts')
  cohorts(@Query('months') months = 6) {
    return this.reports.cohorts(Number(months));
  }

  /** Weekly e-mail of the overview to the merchant's team. */
  @RequireModule('advanced_reports')
  @Post('schedules')
  schedule(@Body() body: { cadence: 'weekly'; recipients: string[] }) {
    return this.reports.schedule(body);
  }

  /** The pre-2026 summary endpoint. */
  @RequireModule('reports')
  @Get('legacy-summary')
  legacySummary() {
    return this.reports.overview('90d');
  }
}
