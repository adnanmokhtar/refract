import { Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { TenantGuard, TenantRequest } from '../auth/tenant.guard';
import { Roles, RolesGuard } from '../auth/roles.guard';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(TenantGuard, RolesGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // Overrides the risk score and the refund window: refunds the full capture immediately.
  @Post('returns/:id/force-refund')
  @Roles('admin')
  forceRefund(@Req() req: TenantRequest, @Param('id') id: string) {
    return this.admin.forceRefund(req.tenantId, id, req.agentId);
  }

  @Get('agents')
  @Roles('admin')
  agents(@Req() req: TenantRequest) {
    return this.admin.listAgents(req.tenantId);
  }

  @Get('agents/:id')
  @Roles('admin')
  agent(@Req() req: TenantRequest, @Param('id') id: string) {
    return this.admin.getAgent(req.tenantId, id);
  }

  @Post('agents/:id/disable')
  @Roles('admin')
  disableAgent(@Req() req: TenantRequest, @Param('id') id: string) {
    return this.admin.disableAgent(req.tenantId, id);
  }
}
