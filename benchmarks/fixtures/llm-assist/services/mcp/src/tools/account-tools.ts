import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { db } from '../db.js';

export function registerAccountTools(server: McpServer): void {
  server.registerTool(
    'get_account',
    { description: 'Get a customer account with its plan, seats and billing contact.', inputSchema: { accountId: z.string() } },
    async (args) => {
      const { rows } = await db.query('SELECT id, name, plan, seats, billing_email FROM accounts WHERE id = $1', [args.accountId]);
      return { content: [{ type: 'text', text: JSON.stringify(rows[0] ?? null) }] };
    },
  );
}
