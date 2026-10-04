import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CheckoutDto } from './checkout.dto';
import { CheckoutService } from './checkout.service';
import { OrdersService } from './orders.service';

@Controller('orders')
@UseGuards(JwtAuthGuard)
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly checkout: CheckoutService,
  ) {}

  @Post('checkout')
  createOrder(@Req() req: { user: AuthUser }, @Body() body: CheckoutDto) {
    return this.checkout.createOrder(req.user.sub, body);
  }

  @Get('mine')
  mine(@Req() req: { user: AuthUser }) {
    return this.orders.listForBuyer(req.user.sub);
  }

  @Get('selling')
  selling(
    @Req() req: { user: AuthUser },
    @Query('sort') sort?: string,
    @Query('dir') dir?: string,
    @Query('page') page?: string,
  ) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.orders.listForSeller(req.user.sub, sort, dir, Number(page) || 1);
  }

  @Post(':id/ship')
  ship(@Req() req: { user: AuthUser }, @Param('id', ParseUUIDPipe) id: string) {
    return this.orders.markShipped(id, req.user.sub);
  }
}
