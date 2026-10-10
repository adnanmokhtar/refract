import type { SQSEvent } from 'aws-lambda';
import { retryPayout } from './payouts';

// Re-attempts payouts the PSP rejected with a retryable code.
export const handler = async (event: SQSEvent): Promise<void> => {
  for (const record of event.Records) {
    try {
      await retryPayout(JSON.parse(record.body));
    } catch (err) {
      console.error({ err, messageId: record.messageId }, 'payout retry failed');
    }
  }
};
