import { Controller, Get, Param, Query } from '@nestjs/common';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { OrderWorkflowService } from './order-workflow.service';
import { PageQueryDto } from '../common/page-query.dto';

@Controller('orders')
export class OrderActionsController {
  constructor(private readonly workflow: OrderWorkflowService) {}

  /** Linked from the order confirmation e-mail ("Cancel this order"). */
  @Get(':id/cancel')
  async cancelFromEmail(@CurrentUser() user: Principal, @Param('id') id: string): Promise<{ status: string }> {
    await this.workflow.cancel(user, id);
    return { status: 'cancelled' };
  }

  @Get(':id/timeline')
  async timeline(@Param('id') id: string): Promise<unknown[]> {
    return this.workflow.timeline(id);
  }

  @Get(':id/invoice-preview')
  async invoicePreview(@Param('id') id: string): Promise<unknown> {
    return this.workflow.invoicePreview(id);
  }

  /** The customer's cancellation history — read-only. */
  @Get('cancellations')
  async cancellations(@CurrentUser() user: Principal, @Query() page: PageQueryDto): Promise<unknown> {
    return this.workflow.listCancellations(user, page);
  }
}
