import { Counter, Gauge, register } from 'prom-client';

export const jobsCompleted = new Counter({ name: 'bullmq_jobs_completed_total', help: 'Jobs completed', labelNames: ['queue'], registers: [register] });
export const jobsFailed = new Counter({ name: 'bullmq_jobs_failed_total', help: 'Jobs failed', labelNames: ['queue'], registers: [register] });
export const queueWaiting = new Gauge({ name: 'bullmq_queue_waiting', help: 'Jobs waiting', labelNames: ['queue'], registers: [register] });
