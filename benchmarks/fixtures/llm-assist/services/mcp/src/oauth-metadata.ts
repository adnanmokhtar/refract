import type { Express } from 'express';

const ISSUER = process.env.AUTH_ISSUER ?? 'https://id.quilldesk.example';
const RESOURCE = process.env.MCP_RESOURCE_URL ?? 'https://mcp.quilldesk.example/mcp';

export function mountOAuthMetadata(app: Express): void {
  app.get('/.well-known/oauth-protected-resource', (_req, res) => {
    res.json({
      resource: RESOURCE,
      authorization_servers: [ISSUER],
      scopes_supported: ['*', 'tickets:read', 'tickets:write', 'accounts:read'],
      bearer_methods_supported: ['header'],
    });
  });
}
