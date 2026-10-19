import express from 'express';

/**
 * The pre-2025 SSE endpoint still used by two desktop integrations. The session id issued on
 * GET /sse is the only credential the POST /messages call presents.
 */
const sessions = new Map<string, { tenantId: string; res: express.Response }>();
let nextSession = 1000;

export const legacy = express.Router();

legacy.get('/sse', (req, res) => {
  const sessionId = String(nextSession++);
  sessions.set(sessionId, { tenantId: String(req.query.tenant ?? ''), res });
  res.setHeader('content-type', 'text/event-stream');
  res.write(`event: endpoint\ndata: /messages?sessionId=${sessionId}\n\n`);
});

legacy.post('/messages', express.json(), (req, res) => {
  const session = sessions.get(String(req.query.sessionId));
  if (!session) {
    res.status(404).end();
    return;
  }
  session.res.write(`data: ${JSON.stringify({ tenantId: session.tenantId, request: req.body })}\n\n`);
  res.status(202).end();
});
