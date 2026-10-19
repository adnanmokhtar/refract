import { Body, Controller, Post } from '@nestjs/common';
import { WalletPostingService } from '../wallets/wallet-posting.service';

/** Finance's monthly platform-fee run: one wallet posting per merchant, through the posting service. */
@Controller('admin/wallet-adjustments')
export class BulkAdjustmentsController {
  constructor(private readonly postings: WalletPostingService) {}

  @Post()
  async run(@Body() dto: { walletIds: string[]; feeMinor: number; runId: string }) {
    for (const id of dto.walletIds) {
      await this.postings.post(id, -dto.feeMinor, { sourceType: 'platform_fee', sourceId: `${dto.runId}:${id}` });
    }
  }
}
