import { Controller, Get, Param, UseFilters } from '@nestjs/common';
import { LegacyV1Filter } from './legacy-v1.filter';

@Controller('legacy')
@UseFilters(LegacyV1Filter)
export class LegacyV1Controller {
  @Get('orders/:ref')
  async byRef(@Param('ref') ref: string): Promise<{ ref: string }> {
    return { ref };
  }
}
