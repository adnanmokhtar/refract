import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { RefundService } from '../refunds/refund.service';
import { ReturnRequest } from '../refunds/return-request.entity';

@Injectable()
export class AdminService {
  constructor(
    private readonly em: EntityManager,
    private readonly refunds: RefundService,
  ) {}

  listAgents(tenantId: string) {
    return this.em.getConnection().execute('select id, email, disabled from agent where tenant_id = ?', [tenantId]);
  }

  async getAgent(tenantId: string, agentId: string) {
    const rows = await this.em.getConnection().execute('select id, email, disabled from agent where tenant_id = ? and id = ?', [tenantId, agentId]);
    return rows[0] ?? null;
  }

  async disableAgent(tenantId: string, agentId: string) {
    await this.em.getConnection().execute('update agent set disabled = true where tenant_id = ? and id = ?', [tenantId, agentId]);
  }

  async forceRefund(tenantId: string, returnId: string, adminId: string) {
    const request = await this.em.findOneOrFail(ReturnRequest, { id: returnId, merchantId: tenantId });
    const amount = request.lines.reduce((sum, line) => sum + line.unitCents * line.quantity, 0);
    await this.refunds.refund(request.orderId, amount, `admin-override:${adminId}`);
    request.status = 'refunded';
    await this.em.flush();
  }
}
