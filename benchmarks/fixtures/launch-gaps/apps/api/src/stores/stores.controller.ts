import { Body, Controller, Delete, Get, Param, Post, Put } from '@nestjs/common';
import { RequireModule } from '../entitlements/require-module.decorator';
import { StoresService } from './stores.service';

@RequireModule('inventory')
@Controller('stores')
export class StoresController {
  constructor(private readonly stores: StoresService) {}

  @Get()
  list() {
    return this.stores.list();
  }

  @Post()
  connect(@Body() body: { type: 'shopify' | 'woocommerce' | 'manual'; name: string }) {
    return this.stores.connect(body);
  }

  @Put(':id/sync')
  sync(@Param('id') id: string) {
    return this.stores.sync(id);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.stores.remove(id);
  }
}
