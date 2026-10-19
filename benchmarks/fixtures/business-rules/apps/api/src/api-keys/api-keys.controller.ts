import { Body, Controller, Get, Param, Post } from '@nestjs/common';

/** Merchant API keys for their own storefront integrations. */
@Controller('api-keys')
export class ApiKeysController {
  @Get()
  list() {
    return [];
  }

  @Post()
  create(@Body() dto: { label: string }) {
    return { id: 'key_1', label: dto.label };
  }

  @Post(':id/revoke')
  revoke(@Param('id') id: string) {
    return { id, revoked: true };
  }
}
