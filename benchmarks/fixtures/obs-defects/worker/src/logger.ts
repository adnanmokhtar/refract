import { trace } from '@opentelemetry/api';
import winston from 'winston';

// Trace correlation for every worker line: the active span's ids, added by hand.
const withTraceIds = winston.format((info) => {
  const ctx = trace.getActiveSpan()?.spanContext();
  return ctx ? { ...info, traceId: ctx.traceId, spanId: ctx.spanId } : info;
});

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? 'info',
  format: winston.format.combine(withTraceIds(), winston.format.timestamp(), winston.format.json()),
  transports: [new winston.transports.Console()],
});

export function moduleLogger(module: string): winston.Logger {
  return logger.child({ module });
}
