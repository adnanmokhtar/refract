import { Body, Controller, Post } from '@nestjs/common';
import { CreateRefundDto } from './dto/create-refund.dto';
import { RefundsService } from './refunds.service';

@Controller('refunds')
export class RefundsController {
  constructor(private readonly refunds: RefundsService) {}

  @Post()
  create(@Body() dto: CreateRefundDto) {
    return this.refunds.create(dto);
  }
}
