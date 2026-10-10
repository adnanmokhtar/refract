import http from 'node:http';
import { Counter, Gauge, Histogram, Summary, register } from 'prom-client';

export const jobsTotal = new Counter({
  name: 'worker_jobs_total',
  help: 'Jobs processed by queue and outcome',
  labelNames: ['queue', 'outcome'],
});

export const jobDuration = new Histogram({
  name: 'worker_job_duration_seconds',
  help: 'Job processing duration in seconds',
  labelNames: ['queue'],
  buckets: [0.1, 0.5, 1, 5, 15, 60],
});

export const invoiceRender = new Summary({
  name: 'invoice_render_seconds',
  help: 'Invoice PDF render time',
  percentiles: [0.5, 0.9, 0.99],
});

export const queueWaiting = new Gauge({
  name: 'queue_waiting_jobs',
  help: 'Jobs waiting in each BullMQ queue',
  labelNames: ['queue'],
});

export function startMetricsServer(port: number): void {
  http
    .createServer(async (_req, res) => {
      res.setHeader('Content-Type', register.contentType);
      res.end(await register.metrics());
    })
    .listen(port);
}
