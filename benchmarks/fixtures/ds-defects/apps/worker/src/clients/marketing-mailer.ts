import { Injectable } from '@nestjs/common';
import { request } from 'undici';

@Injectable()
export class MarketingMailer {
  async sendCampaign(campaignId: string, merchantId: string, signal: AbortSignal): Promise<void> {
    await request(`${process.env.MARKETING_API_URL}/campaigns/${campaignId}/recipients/${merchantId}/send`, { method: 'PUT', signal });
  }
}
