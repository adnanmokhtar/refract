import { Injectable } from '@nestjs/common';
import { ANY, jsonEvent, KurrentDBClient } from '@kurrent/kurrentdb-client';

/**
 * Append-only audit trail of admin actions, one stream per tenant. Nothing is decided from this stream's state:
 * entries are facts recorded after the action, read only by the audit export.
 */
@Injectable()
export class AuditTrail {
  constructor(private readonly client: KurrentDBClient) {}

  async record(tenantId: string, actor: string, action: string, details: Record<string, unknown>): Promise<void> {
    const event = jsonEvent({ type: 'AdminActionRecorded', data: { actor, action, details, at: new Date().toISOString() } });
    await this.client.appendToStream(`audit-${tenantId}`, event, { streamState: ANY });
  }
}
