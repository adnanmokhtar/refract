import { Controller, Get, Param, Query, Req, Res, UseGuards } from '@nestjs/common';
import type { FastifyReply } from 'fastify';
import { AuthUser } from '../auth/auth-user';
import { StoreStaffGuard } from '../stores/store-staff.guard';
import { OrderDetailService } from './order-detail.service';
import { OrderHistoryService } from './order-history.service';
import { SellerOrdersService } from './seller-orders.service';

@Controller()
export class OrdersController {
  constructor(
    private readonly history: OrderHistoryService,
    private readonly detail: OrderDetailService,
    private readonly seller: SellerOrdersService,
  ) {}

  @Get('me/orders')
  mine(@Req() req: { user: AuthUser; customerIds: string[] }, @Query('before') before?: string, @Query('beforeId') beforeId?: string) {
    const cursor = before && beforeId ? { before: new Date(before), beforeId } : undefined;
    return this.history.listForCustomer(req.customerIds, cursor);
  }

  @Get('me/orders/:id')
  one(@Req() req: { user: AuthUser }, @Param('id') id: string) {
    return this.detail.getDetail(id, req.user.id);
  }

  @Get('me/orders/:id/invoice.pdf')
  async invoice(@Req() req: { user: AuthUser }, @Param('id') id: string, @Res() reply: FastifyReply) {
    const { url } = await this.detail.invoiceLink(id, req.user.id);
    return reply.redirect(url, 302);
  }

  @Get('stores/:storeId/orders/recent')
  @UseGuards(StoreStaffGuard)
  recent(@Param('storeId') storeId: string, @Query('status') status?: string) {
    return this.seller.recentForStore(storeId, status);
  }

  @Get('stores/:storeId/orders/recent-lines')
  @UseGuards(StoreStaffGuard)
  recentLines(@Param('storeId') storeId: string) {
    return this.history.recentLinesForStore(storeId);
  }

  @Get('stores/:storeId/orders/export.csv')
  @UseGuards(StoreStaffGuard)
  async export(@Param('storeId') storeId: string, @Res() reply: FastifyReply) {
    const csv = await this.seller.exportCsv(storeId);
    return reply.header('content-type', 'text/csv; charset=utf-8').header('content-disposition', 'attachment; filename="orders.csv"').send(csv);
  }
}
