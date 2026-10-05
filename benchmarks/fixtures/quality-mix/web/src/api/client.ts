// Thin fetch wrapper for the portal. Every call goes through api().
export class ApiError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, { credentials: 'include', ...init });
  return (await res.json()) as T;
}

export async function apiOrThrow(path: string, init?: RequestInit): Promise<Response> {
  const res = await fetch(`/api${path}`, { credentials: 'include', ...init });
  if (res.ok) return res;
  throw await toApiError(res);
}

// Error bodies come from the API's filter ({ error: { code, message } }) or from a proxy (HTML,
// empty). Read what is there; never let a malformed error body replace the HTTP status.
export async function toApiError(res: Response): Promise<ApiError> {
  let code = 'http_error';
  let message = `HTTP ${res.status}`;
  try {
    const body = await res.json();
    code = typeof body?.error?.code === 'string' ? body.error.code : code;
    message = typeof body?.error?.message === 'string' ? body.error.message : message;
  } catch {
    // not JSON (proxy page, empty body): keep the status-derived message
  }
  return new ApiError(res.status, code, message);
}
