import { Controller, Get, Param, Req, UseGuards } from '@nestjs/common';
import { TenantGuard, TenantRequest } from '../auth/tenant.guard';
import { OrdersService } from './orders.service';

@Controller('orders')
@UseGuards(TenantGuard)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  recent(@Req() req: TenantRequest) {
    return this.orders.recent(req.tenantId);
  }

  // Refund amounts are shown to the merchant's agents only; another tenant's order must read as 404.
  @Get(':id')
  get(@Req() req: TenantRequest, @Param('id') id: string) {
    return this.orders.get(req.tenantId, id);
  }
}
