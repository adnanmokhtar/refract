import { Controller, Get, NotFoundException, Query } from '@nestjs/common';

const REGIONS = new Map<string, { code: string; vatRate: string }>([
  ['ae', { code: 'ae', vatRate: '0.05' }],
  ['sa', { code: 'sa', vatRate: '0.15' }],
]);

function assertRegion(region: unknown): asserts region is string {
  if (typeof region !== 'string' || !REGIONS.has(region)) throw new NotFoundException('Unknown region');
}

@Controller('regions')
export class RegionsController {
  @Get('vat')
  async vat(@Query('region') region: string): Promise<{ code: string; vatRate: string }> {
    assertRegion(region);
    return REGIONS.get(region)!;
  }
}
