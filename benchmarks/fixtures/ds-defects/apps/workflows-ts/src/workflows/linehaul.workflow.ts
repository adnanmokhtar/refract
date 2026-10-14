import { proxyActivities } from '@temporalio/workflow';
import type * as acts from '../activities';

const { reserveTrailerCapacity } = proxyActivities<typeof acts>({
  startToCloseTimeout: '2 minutes',
  retry: { maximumAttempts: 4 },
});

const { bookLinehaul } = proxyActivities<typeof acts>({ startToCloseTimeout: '1 minute' });

/** Books the nightly linehaul trailer between two depots for a consolidated pallet. */
export async function linehaulWorkflow(palletId: string, fromDepot: string, toDepot: string): Promise<string> {
  await reserveTrailerCapacity(fromDepot, toDepot);
  return bookLinehaul(palletId, fromDepot, toDepot);
}
