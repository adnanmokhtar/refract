import { spawn } from 'node:child_process';
import http from 'node:http';

/**
 * Local developer bridge: exposes the stdio build of the server over HTTP so the MCP Inspector and
 * a browser playground can talk to it. Start with `pnpm bridge`.
 */
const child = spawn('node', ['dist/stdio.js'], { stdio: ['pipe', 'pipe', 'inherit'] });

http
  .createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      child.stdin.write(body + '\n');
      child.stdout.once('data', (out) => {
        res.setHeader('access-control-allow-origin', '*');
        res.end(out);
      });
    });
  })
  .listen(6277, '0.0.0.0');
