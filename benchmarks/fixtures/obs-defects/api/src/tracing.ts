import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { IORedisInstrumentation } from '@opentelemetry/instrumentation-ioredis';
import { NestInstrumentation } from '@opentelemetry/instrumentation-nestjs-core';
import { PgInstrumentation } from '@opentelemetry/instrumentation-pg';

// Tracing bootstrap for the API process. Spans go to the collector gateway (OTEL_EXPORTER_OTLP_ENDPOINT).
const sdk = new NodeSDK({
  serviceName: 'api',
  traceExporter: new OTLPTraceExporter(),
  instrumentations: [
    new HttpInstrumentation(),
    new NestInstrumentation(),
    new PgInstrumentation(),
    new IORedisInstrumentation(),
  ],
});

sdk.start();
