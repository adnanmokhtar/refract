import { Body, Controller, Delete, Get, Param, Post, Req } from '@nestjs/common';
import { ApiKeysService } from './api-keys.service';

/** Keys for the merchant-facing REST API (the API access extension). */
@Controller('api-keys')
export class ApiKeysController {
  constructor(private readonly keys: ApiKeysService) {}

  @Get()
  list(@Req() req: { user: { tenantId: string } }) {
    return this.keys.list(req.user.tenantId);
  }

  @Post()
  create(@Req() req: { user: { tenantId: string } }, @Body() body: { label: string }) {
    return this.keys.create(req.user.tenantId, body.label);
  }

  @Delete(':id')
  revoke(@Req() req: { user: { tenantId: string } }, @Param('id') id: string) {
    return this.keys.revoke(req.user.tenantId, id);
  }
}
