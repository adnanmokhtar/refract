import { Body, Controller, Param, Patch } from '@nestjs/common';
import { UpdateSupplierDto } from './dto/update-supplier.dto';

@Controller('suppliers')
export class SuppliersController {
  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateSupplierDto): Promise<{ id: string }> {
    return { id, ...dto };
  }
}
