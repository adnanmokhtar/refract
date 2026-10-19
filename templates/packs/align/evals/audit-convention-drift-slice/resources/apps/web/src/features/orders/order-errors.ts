import type { HTTPError } from 'ky';

// The API answers errors with RFC 9457 problem details (ADR-0004); show the title it sends.
export async function problemTitle(error: HTTPError): Promise<string> {
  const body = (await error.response.json().catch(() => ({}))) as { title?: string };
  return body.title ?? error.message;
}
