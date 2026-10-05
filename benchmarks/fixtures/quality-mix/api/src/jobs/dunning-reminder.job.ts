import { Injectable } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

// Loaded by JobsModule's glob; runs hourly from the scheduler.
@Injectable()
export class DunningReminderJob {
  constructor(private readonly db: PrismaClient) {}

  async run(): Promise<number> {
    const due = await this.db.$queryRaw<{ id: string }[]>`select id from subscription where status = 'past_due' and reminded_at < now() - interval '3 days'`;
    return due.length;
  }
}
