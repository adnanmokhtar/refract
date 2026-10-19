import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';

export const transports = new Map<string, StreamableHTTPServerTransport>();

export function newTransport(): StreamableHTTPServerTransport {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => Math.random().toString(36).slice(2, 10),
    onsessioninitialized: (id) => {
      transports.set(id, transport);
    },
  });
  transport.onclose = () => {
    if (transport.sessionId) transports.delete(transport.sessionId);
  };
  return transport;
}
