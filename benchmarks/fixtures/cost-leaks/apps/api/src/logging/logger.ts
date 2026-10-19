import winston from 'winston';

// JSON to stdout for the cluster's log shipper, plus a local file the on-call can tail inside the pod.
export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? 'info',
  format: winston.format.combine(winston.format.timestamp(), winston.format.json()),
  defaultMeta: { service: 'quaywise-api' },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: '/var/log/quaywise/api.log' }),
  ],
});
