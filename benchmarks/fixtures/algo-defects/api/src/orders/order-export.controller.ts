import { Body, Controller, Header, Param, Post } from '@nestjs/common';
import { ExportOrdersDto } from './dto/export-orders.dto';
import { OrderExportService } from './order-export.service';

@Controller('stores/:storeId/orders')
export class OrderExportController {
  constructor(private readonly exports: OrderExportService) {}

  @Post('export')
  @Header('Content-Type', 'text/csv')
  exportCsv(@Param('storeId') storeId: string, @Body() dto: ExportOrdersDto): Promise<string> {
    return this.exports.exportSelected(storeId, dto);
  }
}
