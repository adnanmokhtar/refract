import { proxyActivities, sleep } from '@temporalio/workflow';
import type * as acts from '../activities';

const { recomputeMerchantTier } = proxyActivities<typeof acts>({ startToCloseTimeout: '1 minute', retry: { maximumAttempts: 5 } });

/** New in 1.9: recomputes a merchant's volume tier on the first of each month. */
export async function merchantTierWorkflow(merchantId: string): Promise<void> {
  await recomputeMerchantTier(merchantId);
  await sleep('30 days');
}
