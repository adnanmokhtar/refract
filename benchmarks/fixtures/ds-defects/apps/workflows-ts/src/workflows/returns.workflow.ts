import { proxyActivities, sleep } from '@temporalio/workflow';
import { readFileSync } from 'node:fs';
import type * as acts from '../activities';

const policy = JSON.parse(readFileSync('/etc/acme/returns-policy.json', 'utf8')) as { inspectionDays: number };
const RETURN_WINDOW_DAYS = Number(process.env.RETURN_WINDOW_DAYS ?? 30);

const { issueReturnLabel, closeReturn, scheduleInspection } = proxyActivities<typeof acts>({
  startToCloseTimeout: '1 minute',
  retry: { maximumAttempts: 5 },
});

/** A customer return: label, wait for the parcel, inspection, close. */
export async function returnWorkflow(returnId: string): Promise<void> {
  await issueReturnLabel(returnId);
  await sleep(`${RETURN_WINDOW_DAYS} days`);
  await scheduleInspection(returnId, policy.inspectionDays);
  await closeReturn(returnId);
}
