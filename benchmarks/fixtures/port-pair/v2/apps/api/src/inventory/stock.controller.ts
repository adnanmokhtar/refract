import { Controller, Get, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import { ReserveStockBody, type ReserveStockBodyT } from '@norrow/contracts';
import type { FastifyRequest } from 'fastify';
import { type AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Permissions } from '../common/permissions.decorator';
import { ZodBody } from '../common/zod';
import { importStockCsv } from './csv-import';
import { StockRepository } from './stock.repository';
import { StockService } from './stock.service';

@Controller('stock')
export class StockController {
  constructor(private readonly repo: StockRepository, private readonly stock: StockService) {}

  @Get()
  list(@Query('page') page = '1') {
    return this.stock.list(Number(page));
  }

  // V1 GET /stock/low-stock, renamed (ADR-0004, pair-map row).
  @Get('alerts')
  alerts(@CurrentUser() user: AuthUser) {
    return this.repo.lowStock(user.accountId);
  }

  @Post('import')
  @Permissions('stock:import')
  @HttpCode(202)
  async import(@Req() req: FastifyRequest, @CurrentUser() user: AuthUser) {
    const file = await req.file();
    return { data: await importStockCsv(this.stock, (await file!.toBuffer()).toString('utf8'), user.accountId) };
  }

  @Get(':sku')
  async show(@Param('sku') sku: string, @CurrentUser() user: AuthUser) {
    return this.stock.show(sku, user.accountId);
  }

  @Post(':sku/reserve')
  @Permissions('stock:reserve')
  @HttpCode(200)
  reserve(@Param('sku') sku: string, @ZodBody(ReserveStockBody) body: ReserveStockBodyT) {
    return this.stock.reserve(sku, body.quantity);
  }
}
