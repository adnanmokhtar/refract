import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';
import { MailerService } from '../mailer/mailer.service';

@Injectable()
export class ReferralsService {
  constructor(
    private readonly em: EntityManager,
    private readonly mailer: MailerService,
  ) {}

  forUser(userId: string) {
    return this.em.find('Referral', { referrer: userId });
  }

  async send(userId: string, email: string) {
    const referral = this.em.create('Referral', { referrer: userId, email, status: 'sent' });
    await this.em.persistAndFlush(referral);
    await this.mailer.queue('referral-invite', email, { referralId: referral.id });
    return referral;
  }
}
