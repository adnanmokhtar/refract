import { Body, Controller, Post } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { Coupon } from './coupon.entity';

@Controller('admin/coupons')
export class CouponsAdminController {
  constructor(private readonly em: EntityManager) {}

  @Post()
  async create(@Body() dto: { code: string; kind: 'percent' | 'fixed'; value: number; expiresOn: string }) {
    const coupon = this.em.create(Coupon, {
      code: dto.code,
      kind: dto.kind,
      percentOff: dto.kind === 'percent' ? dto.value : 0,
      amountOffMinor: dto.kind === 'fixed' ? dto.value : 0,
      expiresAt: new Date(dto.expiresOn),
    });
    await this.em.persistAndFlush(coupon);
    return coupon;
  }
}
