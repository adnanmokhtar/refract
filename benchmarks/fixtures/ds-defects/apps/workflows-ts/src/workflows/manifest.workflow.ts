import { proxyActivities } from '@temporalio/workflow';
import type * as acts from '../activities';

/** The carrier's end-of-day manifest upload: every parcel of the day, one EDI file per carrier. */
const { buildAndUploadManifest } = proxyActivities<typeof acts>({
  startToCloseTimeout: '2 hours',
  heartbeatTimeout: '1 minute',
  retry: { maximumAttempts: 3 },
});

export async function endOfDayManifestWorkflow(carrier: string, day: string): Promise<void> {
  await buildAndUploadManifest(carrier, day);
}
