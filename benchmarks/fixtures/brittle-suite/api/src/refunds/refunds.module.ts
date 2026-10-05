import { Module } from '@nestjs/common';
import { MikroOrmModule } from '@mikro-orm/nestjs';
import { Refund } from './refund.entity';
import { ReturnRequest } from './return-request.entity';
import { RefundController } from './refund.controller';
import { RefundService } from './refund.service';
import { RefundApprovalService } from './refund-approval.service';
import { RefundBatchService } from './refund-batch.service';
import { ReturnRepository } from './return.repository';

@Module({
  imports: [MikroOrmModule.forFeature([Refund, ReturnRequest])],
  controllers: [RefundController],
  providers: [RefundService, RefundApprovalService, RefundBatchService, ReturnRepository],
  exports: [RefundService],
})
export class RefundsModule {}
