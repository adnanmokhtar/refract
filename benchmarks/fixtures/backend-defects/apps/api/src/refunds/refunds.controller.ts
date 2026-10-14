import { Body, Controller, HttpCode, Param, Post } from '@nestjs/common';
import { ArrayMaxSize, IsInt, IsString, Max, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { OrderWorkflowService } from '../orders/order-workflow.service';
import { RefundLinesService } from './refund-lines.service';

export class RefundLineDto {
  @IsString()
  sku!: string;

  @IsInt()
  @Min(1)
  @Max(999)
  quantity!: number;
}

export class PartialRefundDto {
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => RefundLineDto)
  lines!: RefundLineDto[];
}

@Controller('orders/:id/refunds')
export class RefundsController {
  constructor(private readonly workflow: OrderWorkflowService, private readonly lines: RefundLinesService) {}

  @Post('full')
  @HttpCode(200)
  async full(@CurrentUser() user: Principal, @Param('id') id: string): Promise<{ refunded: boolean }> {
    return this.workflow.refund(user, id);
  }

  @Post('partial')
  @HttpCode(200)
  async partial(@Param('id') id: string, @Body() dto: PartialRefundDto): Promise<{ accepted: number }> {
    await this.lines.validate(id, dto.lines);
    return { accepted: dto.lines.length };
  }
}
