import { Body, Controller, NotImplementedException, Post } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';

@RequireModule('reports')
@Controller('exports')
export class ExportsController {
  @Post()
  create(@Body() body: { report: 'overview' | 'orders'; format: 'csv' | 'xlsx' }) {
    void body;
    throw new NotImplementedException('Exports ship with reports v2');
  }
}
