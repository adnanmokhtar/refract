import { PostHog } from 'posthog-node';

export const POSTHOG = Symbol('POSTHOG');

export const PosthogProvider = {
  provide: POSTHOG,
  useFactory: () => new PostHog(process.env.POSTHOG_KEY ?? '', { host: 'https://eu.i.posthog.com', flushAt: 20 }),
};
