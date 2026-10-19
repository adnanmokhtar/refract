import { Injectable } from '@nestjs/common';

@Injectable()
export class ReportsService {
  async monthly(month: string, format: 'json' | 'csv') {
    return format === 'csv' ? 'currency,total_minor\n' : { month, totals: [] };
  }
}
