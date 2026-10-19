import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import express from 'express';
import { requireBearer } from './auth.js';
import { mountOAuthMetadata } from './oauth-metadata.js';
import { newTransport, transports } from './session.js';
import { registerAccountTools } from './tools/account-tools.js';
import { registerDiagnosticsTools } from './tools/diagnostics-tools.js';
import { registerTicketTools } from './tools/ticket-tools.js';

const PORT = Number(process.env.PORT ?? 8787);

function buildServer(): McpServer {
  const server = new McpServer({ name: 'quilldesk', version: '1.6.0' });
  registerTicketTools(server);
  registerAccountTools(server);
  registerDiagnosticsTools(server);
  return server;
}

const app = express();
app.use(express.json({ limit: '1mb' }));
mountOAuthMetadata(app);

app.post('/mcp', requireBearer, async (req, res) => {
  const sessionId = req.header('mcp-session-id');
  let transport = sessionId ? transports.get(sessionId) : undefined;
  if (!transport) {
    transport = newTransport();
    await buildServer().connect(transport);
  }
  await transport.handleRequest(req, res, req.body);
});

app.listen(PORT, '0.0.0.0', () => console.log(`quilldesk MCP listening on ${PORT}`));
