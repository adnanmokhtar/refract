import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({ serviceName: 'fulfilment-api', instrumentations: [getNodeAutoInstrumentations()] });
sdk.start();

process.on('SIGTERM', () => {
  void sdk.shutdown();
});
