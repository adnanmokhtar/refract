import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { TenantGuard } from '../auth/tenant.guard';
import { RefundApprovalService } from './refund-approval.service';

@Controller('returns')
@UseGuards(TenantGuard)
export class RefundController {
  constructor(private readonly approvals: RefundApprovalService) {}

  @Post(':id/approve')
  approve(@Param('id') id: string, @Body() body: { approver: string }) {
    return this.approvals.approve(id, body.approver);
  }

  @Post(':id/refund')
  refund(@Param('id') id: string) {
    return this.approvals.refundApproved(id);
  }
}
