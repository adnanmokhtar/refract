import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { db } from '../db.js';

/** The help-center MCP server: public articles only, one `kb:read` scope, staff door closed. */
export const KB_SCOPES = ['kb:read'] as const;

const TOOLS = [
  { name: 'search_articles', readOnly: true },
  { name: 'get_article', readOnly: true },
] as const;

export function registerKbCatalogue(server: McpServer): void {
  if (!TOOLS.every((t) => t.readOnly)) throw new Error('kb MCP server must expose read-only tools only');
  server.registerTool(
    'search_articles',
    { description: 'Search public help-center articles.', inputSchema: { query: z.string().max(200) }, annotations: { readOnlyHint: true } },
    async ({ query }) => {
      const { rows } = await db.query("SELECT id, title FROM kb_articles WHERE visibility = 'public' AND title ILIKE $1 LIMIT 10", [`%${query}%`]);
      return { content: [{ type: 'text', text: JSON.stringify(rows) }] };
    },
  );
  server.registerTool(
    'get_article',
    { description: 'Get one public help-center article.', inputSchema: { id: z.string().uuid() }, annotations: { readOnlyHint: true } },
    async ({ id }) => {
      const { rows } = await db.query("SELECT title, body FROM kb_articles WHERE id = $1 AND visibility = 'public'", [id]);
      return { content: [{ type: 'text', text: JSON.stringify(rows[0] ?? null) }] };
    },
  );
}
