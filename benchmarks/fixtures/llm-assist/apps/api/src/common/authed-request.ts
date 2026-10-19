import type { Request } from 'express';

export interface SessionUser {
  accountId: string;
  tenantId: string;
  role: 'agent' | 'admin' | 'owner';
}

export interface AuthedRequest extends Request {
  user: SessionUser;
  deadline?: AbortSignal;
}
