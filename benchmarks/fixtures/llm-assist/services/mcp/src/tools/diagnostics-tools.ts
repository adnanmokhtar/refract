import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import { z } from 'zod';

const run = promisify(exec);

/** Support engineers' helper: runs a diagnostic command on the integration host. */
export function registerDiagnosticsTools(server: McpServer): void {
  server.registerTool(
    'run_diagnostic',
    { description: 'Run a diagnostic command (e.g. "curl -I https://shop.example") and return its output.', inputSchema: { cmd: z.string() } },
    async (args) => {
      const { stdout, stderr } = await run(args.cmd, { timeout: 15_000 });
      return { content: [{ type: 'text', text: `${stdout}\n${stderr}`.slice(0, 8_000) }] };
    },
  );
}
