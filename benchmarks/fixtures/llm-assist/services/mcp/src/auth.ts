import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';

const PUBLIC_KEY = process.env.AUTH_PUBLIC_KEY_PEM ?? '';

export interface McpCaller {
  sub: string;
  tenantId: string;
  scope: string;
}

/** Bearer tokens issued by the Quill Desk identity service. */
export function requireBearer(req: Request, res: Response, next: NextFunction): void {
  const token = req.headers.authorization?.replace(/^Bearer /, '');
  if (!token) {
    res.status(401).set('WWW-Authenticate', 'Bearer resource_metadata="/.well-known/oauth-protected-resource"').end();
    return;
  }
  try {
    const claims = jwt.verify(token, PUBLIC_KEY, { algorithms: ['RS256'] }) as jwt.JwtPayload;
    res.locals.caller = { sub: claims.sub, tenantId: claims.tid, scope: claims.scope ?? '' } satisfies McpCaller;
    next();
  } catch {
    res.status(401).end();
  }
}
