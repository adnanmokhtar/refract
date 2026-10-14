import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { EntityManager } from '@mikro-orm/core';
import { sendDigest } from './mailer';

@Injectable()
export class DigestScheduler {
  constructor(private readonly em: EntityManager) {}

  /** Hourly "what changed" e-mail to every merchant user who opted in. */
  @Cron(CronExpression.EVERY_HOUR, { name: 'merchant-digest', timeZone: 'UTC', waitForCompletion: true })
  async sendHourlyDigests(): Promise<void> {
    const users = await this.em.getConnection().execute('select user_id from digest_optins where active');
    for (const u of users) await sendDigest(u.user_id);
  }
}
