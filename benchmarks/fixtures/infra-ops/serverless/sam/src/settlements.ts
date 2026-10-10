import type { SQSBatchResponse, SQSEvent } from 'aws-lambda';
import { applySettlementFile } from './settlement-file';

export const handler = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  const batchItemFailures: SQSBatchResponse['batchItemFailures'] = [];
  for (const record of event.Records) {
    try {
      await applySettlementFile(JSON.parse(record.body));
    } catch (err) {
      console.error({ err, messageId: record.messageId }, 'settlement file failed');
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }
  return { batchItemFailures };
};
