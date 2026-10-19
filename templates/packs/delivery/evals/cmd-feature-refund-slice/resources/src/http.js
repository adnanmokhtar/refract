// HTTP helpers shared by every handler.

export class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export function json(status, body) {
  return { status, headers: { 'content-type': 'application/json' }, body };
}

export function html(body) {
  return { status: 200, headers: { 'content-type': 'text/html; charset=utf-8' }, body };
}
