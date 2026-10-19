import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { admitUsage } from './quota';
import { retentionCutoff } from './retention';

@Injectable()
export class UsageService {
  constructor(private readonly db: PrismaClient) {}

  async record(accountId: string, units: number) {
    const account = await this.db.$queryRaw<{ plan: string; quota: number; used: number }[]>`select plan, quota, used from usage_account where id = ${accountId}`;
    const decision = admitUsage({ plan: account[0].plan, quota: account[0].quota, usedUnits: account[0].used }, units);
    if (decision.admitted) await this.db.$executeRaw`update usage_account set used = used + ${units} where id = ${accountId}`;
    return decision;
  }

  history(accountId: string, days: number) {
    return this.db.$queryRaw`select day, units from usage_day where account_id = ${accountId} and day >= ${retentionCutoff(days)} order by day`;
  }

  export(accountId: string, limit: number) {
    return this.db.$queryRaw`select day, units from usage_day where account_id = ${accountId} order by day limit ${limit}`;
  }
}
