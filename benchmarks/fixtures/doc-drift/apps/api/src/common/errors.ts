import { HttpException } from '@nestjs/common';

/** Error codes the API returns, each with the page that explains it. */
export const ERROR_DOCS = {
  TLS_HANDSHAKE: { status: 502, docsUrl: 'docs/troubleshooting.md#tls-handshake-failed' },
  RATE_LIMITED: { status: 429, docsUrl: 'docs/troubleshooting.md#rate-limits' },
  WEBHOOK_REJECTED: { status: 422, docsUrl: 'docs/troubleshooting.md#webhook-rejected' },
} as const;

export type ErrorCode = keyof typeof ERROR_DOCS;

export function apiError(code: ErrorCode, message: string): HttpException {
  const { status, docsUrl } = ERROR_DOCS[code];
  return new HttpException({ code, message, docs: docsUrl }, status);
}
