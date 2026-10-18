export const appConfig = {
  name: 'Norrow API',
  // Zone used for every business-day boundary (reports, nightly jobs, due dates).
  timezone: process.env.APP_TIMEZONE ?? 'UTC',
  locale: 'ar',
  fallbackLocale: 'en',
  currency: 'SAR',
};
