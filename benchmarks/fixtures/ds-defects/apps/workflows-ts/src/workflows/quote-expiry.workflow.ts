import { condition, defineSignal, proxyActivities, setHandler } from '@temporalio/workflow';
import type * as acts from '../activities';

/**
 * A freight quote holds a linehaul slot for 15 minutes. If the merchant accepts in time, the slot is booked;
 * otherwise the hold is released and the quote is dead (the carrier re-prices after 15 minutes).
 */
const { bookHeldSlot, releaseHeldSlot } = proxyActivities<typeof acts>({
  startToCloseTimeout: '30 minutes',
  retry: { maximumAttempts: 3 },
});

export const acceptSignal = defineSignal('accept');

export async function quoteHoldWorkflow(quoteId: string): Promise<'booked' | 'expired'> {
  let accepted = false;
  setHandler(acceptSignal, () => {
    accepted = true;
  });
  if (await condition(() => accepted, '15 minutes')) {
    await bookHeldSlot(quoteId);
    return 'booked';
  }
  await releaseHeldSlot(quoteId);
  return 'expired';
}
