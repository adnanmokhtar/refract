import { Body, Controller, Get, Param, Post } from '@nestjs/common';

/** A store links its own courier account (API key from the carrier) to print labels at its rates. */
@Controller('stores/:storeId/carriers')
export class CarrierConnectionsController {
  @Get()
  list(@Param('storeId') storeId: string) {
    return [];
  }

  @Post('connect')
  connect(@Param('storeId') storeId: string, @Body() dto: { carrier: string; apiKey: string }) {
    return { storeId, carrier: dto.carrier, connected: true };
  }
}
