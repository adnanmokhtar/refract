import { Body, Controller, Get, Param, Post } from '@nestjs/common';

/** Sales-channel integrations (marketplaces, social shops). */
@Controller('stores/:storeId/integrations')
export class IntegrationsController {
  @Get()
  list(@Param('storeId') storeId: string) {
    return [];
  }

  @Post()
  connect(@Param('storeId') storeId: string, @Body() dto: { channel: string }) {
    return { id: 'int_1', channel: dto.channel };
  }

  @Post(':integrationId/disconnect')
  disconnect(@Param('storeId') storeId: string, @Param('integrationId') integrationId: string) {
    return { id: integrationId, disconnected: true };
  }
}
