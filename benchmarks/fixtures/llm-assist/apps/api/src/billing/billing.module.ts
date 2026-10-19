import { Module } from '@nestjs/common';
import { CreditWalletService } from './credit-wallet.service';
import { StreamMeter } from './token-estimate';
import { UsageRecorder } from './usage-recorder';

@Module({
  providers: [CreditWalletService, UsageRecorder, StreamMeter],
  exports: [CreditWalletService, UsageRecorder, StreamMeter],
})
export class BillingModule {}
