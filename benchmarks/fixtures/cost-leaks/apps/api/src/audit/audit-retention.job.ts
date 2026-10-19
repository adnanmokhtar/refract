import { Injectable } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/postgresql';
import { subYears } from 'date-fns';
import { AuditLogEntry } from './audit-log.entity';

// The floor is set by docs/compliance/retention.md (financial audit trail, enterprise contracts).
const AUDIT_LOG_RETENTION_YEARS = 7;

@Injectable()
export class AuditRetentionJob {
  constructor(private readonly em: EntityManager) {}

  @Cron('15 4 * * 0')
  async purge(): Promise<number> {
    const cutoff = subYears(new Date(), AUDIT_LOG_RETENTION_YEARS);
    return this.em.fork().nativeDelete(AuditLogEntry, { createdAt: { $lt: cutoff } });
  }
}
