import { Module } from '@nestjs/common';
import { MailerService } from '../mail/mailer.service';
import { PayoutLedgerService } from './payout-ledger.service';
import { PayoutReminderCron } from './payout-reminder.cron';

@Module({
  providers: [PayoutLedgerService, PayoutReminderCron, MailerService],
  exports: [PayoutLedgerService],
})
export class PayoutsModule {}
