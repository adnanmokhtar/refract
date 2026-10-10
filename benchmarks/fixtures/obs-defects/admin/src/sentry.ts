import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: 'https://9a8b7c6d5e4f40312a1b2c3d4e5f6a7b@o450101.ingest.sentry.io/4507002',
  release: 'admin@1.4.0',
  environment: import.meta.env.MODE,
  tracesSampleRate: 0.1,
});
