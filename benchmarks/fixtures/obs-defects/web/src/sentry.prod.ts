import * as Sentry from '@sentry/react';

// Storefront error and performance monitoring, production bundle.
Sentry.init({
  dsn: 'https://3f1c9d2e7a8b4c5d9e0f1a2b3c4d5e6f@o450101.ingest.sentry.io/4507001',
  integrations: [Sentry.browserTracingIntegration()],

  tracesSampleRate: 1.0,

  sendDefaultPii: true,
});
