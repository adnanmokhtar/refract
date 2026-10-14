import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/core';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { ListCustomersQuery } from './dto/list-customers.query';
import { SearchCustomersDto } from './dto/search-customers.dto';

@Controller('customers')
export class CustomersController {
  constructor(private readonly em: EntityManager) {}

  @Get()
  async list(@CurrentUser() user: Principal, @Query() query: ListCustomersQuery): Promise<unknown> {
    return { tenantId: user.tenantId, active: query.active, page: query.page };
  }

  /** Full-text search over customers: an action, so 200. */
  @Post('search')
  @HttpCode(200)
  async search(@CurrentUser() user: Principal, @Body() dto: SearchCustomersDto): Promise<unknown[]> {
    return [{ tenantId: user.tenantId, q: dto.q }];
  }
}
