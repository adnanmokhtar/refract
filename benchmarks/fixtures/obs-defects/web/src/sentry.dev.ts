import * as Sentry from '@sentry/react';

// Local development only (imported behind import.meta.env.DEV in main.tsx): every trace is kept
// so a developer sees their own clicks; nothing here ships in the production bundle.
Sentry.init({
  dsn: 'https://3f1c9d2e7a8b4c5d9e0f1a2b3c4d5e6f@o450101.ingest.sentry.io/4507001',
  environment: 'development',
  release: 'web@dev',
  integrations: [Sentry.browserTracingIntegration()],
  tracesSampleRate: 1.0,
});
