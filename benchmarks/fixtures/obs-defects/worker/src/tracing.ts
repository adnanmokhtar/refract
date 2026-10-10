import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { IORedisInstrumentation } from '@opentelemetry/instrumentation-ioredis';

// Preloaded with `node --require ./dist/tracing.js` (Dockerfile), so it runs before any job module.
const sdk = new NodeSDK({
  serviceName: process.env.OTEL_SERVICE_NAME ?? 'worker',
  traceExporter: new OTLPTraceExporter(),
  instrumentations: [new IORedisInstrumentation()],
});

sdk.start();

process.on('SIGTERM', () => {
  void sdk.shutdown();
});
