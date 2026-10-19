import { Controller, Get, Param, Query } from '@nestjs/common';
import { ValidationError } from '../common/errors';
import { UsageService } from './usage.service';

@Controller('usage')
export class UsageController {
  constructor(private readonly usage: UsageService) {}

  // Records metered units reported by the customer's own servers.
  @Get(':accountId/record')
  record(@Param('accountId') accountId: string, @Query() query: Record<string, string>) {
    const qty = Number(query.qty);
    return this.usage.record(accountId, qty);
  }

  @Get(':accountId/history')
  history(@Param('accountId') accountId: string) {
    return this.usage.history(accountId, 30);
  }

  @Get(':accountId/summary')
  summary(@Param('accountId') accountId: string) {
    return this.usage.history(accountId, 7);
  }

  // The finance export pages through usage in fixed windows.
  @Get(':accountId/export')
  export(@Param('accountId') accountId: string, @Query('limit') limitRaw: string) {
    const limit = Number.parseInt(limitRaw ?? '100', 10);
    if (!Number.isInteger(limit) || limit < 1 || limit > 1_000) throw new ValidationError('limit must be 1..1000', ['limit']);
    return this.usage.export(accountId, limit);
  }
}
