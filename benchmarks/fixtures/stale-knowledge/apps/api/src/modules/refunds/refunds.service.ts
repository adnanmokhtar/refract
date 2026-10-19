import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { CreateRefundDto } from './dto/create-refund.dto';
import { Refund } from './refund.entity';

@Injectable()
export class RefundsService {
  constructor(private readonly em: EntityManager) {}

  async create(dto: CreateRefundDto): Promise<Refund> {
    const refund = this.em.create(Refund, { orderId: dto.orderId, amountMinor: BigInt(dto.amountMinor) });
    await this.em.persistAndFlush(refund);
    return refund;
  }
}
