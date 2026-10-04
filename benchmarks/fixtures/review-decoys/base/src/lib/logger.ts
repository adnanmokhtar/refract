export const logger = {
  info: (event: string, fields: Record<string, unknown> = {}) => console.log(JSON.stringify({ level: 'info', event, ...fields })),
  warn: (event: string, fields: Record<string, unknown> = {}) => console.log(JSON.stringify({ level: 'warn', event, ...fields })),
  error: (event: string, fields: Record<string, unknown> = {}) => console.log(JSON.stringify({ level: 'error', event, ...fields })),
};
