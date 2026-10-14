import { Worker, Queue } from 'bullmq';
import { sendReceiptEmail } from './mailer';

const connection = { host: 'redis', port: 6379 };

export const receiptsQueue = new Queue('receipts', {
  connection,
  defaultJobOptions: { attempts: 1, removeOnComplete: true },
});

/** Sends the payment receipt the customer needs for VAT reclaim. */
export const receiptWorker = new Worker(
  'receipts',
  async (job) => {
    await sendReceiptEmail(job.data.orderId as string, job.data.email as string);
  },
  { connection, concurrency: 5 },
);
