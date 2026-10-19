/** Build-time configuration read from Vite's import.meta.env. */
export const env = {
  apiBase: import.meta.env.VITE_API_BASE ?? '/api',
  sentryDsn: import.meta.env.VITE_SENTRY_DSN ?? '',
  openaiKey: import.meta.env.VITE_OPENAI_API_KEY ?? '',
};
