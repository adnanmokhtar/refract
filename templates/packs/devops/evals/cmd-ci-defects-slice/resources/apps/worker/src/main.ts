import http from 'node:http';
import { Worker } from 'bullmq';
import pino from 'pino';
import { renderInvoice, sendEmail } from './jobs';

const log = pino({ level: process.env.LOG_LEVEL ?? 'info' });
const connection = { url: process.env.REDIS_URL };
const concurrency = Number(process.env.WORKER_CONCURRENCY ?? 4);

const invoices = new Worker('invoices', renderInvoice, { connection, concurrency });
const emails = new Worker('emails', sendEmail, { connection, concurrency });

for (const w of [invoices, emails]) {
  w.on('failed', (job, err) => log.error({ err, jobId: job?.id, queue: w.name }, 'job failed'));
}

// Liveness for the orchestrator.
http
  .createServer((_req, res) => {
    res.writeHead(200).end('ok');
  })
  .listen(Number(process.env.PORT ?? 8081));
