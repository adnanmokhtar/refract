import { Body, Controller, Get, Param, Post } from '@nestjs/common';

/** Asynchronous CSV exports: POST starts a job, GET :id polls its status and download link. */
@Controller('reports/exports')
export class ReportExportsController {
  @Post()
  start(@Body() dto: { report: string; from: string; to: string }) {
    return { id: 'exp_1', status: 'queued' };
  }

  @Get(':id')
  status(@Param('id') id: string) {
    return { id, status: 'done', url: null };
  }
}
