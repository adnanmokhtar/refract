import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const API_SRC = resolve(__dirname, '../../../../api/src');
const WEB_SRC = resolve(__dirname, '../..');

function files(dir: string, ext: RegExp): string[] {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? files(p, ext) : ext.test(n) ? [p] : [];
  });
}

/** `GET /reports/cohorts` for every @Get / @Post under each @Controller prefix. */
function servedRoutes(): string[] {
  return files(API_SRC, /\.controller\.ts$/).flatMap((f) => {
    const src = readFileSync(f, 'utf8');
    const prefix = /@Controller\(\s*'([^']*)'/.exec(src)?.[1] ?? '';
    return [...src.matchAll(/@(Get|Post)\(\s*(?:'([^']*)')?\s*\)/g)].map(
      (m) => `${m[1].toUpperCase()} /${[prefix, m[2] ?? ''].filter(Boolean).join('/')}`,
    );
  });
}

function clientPaths(): string {
  return files(WEB_SRC, /\.tsx?$/).map((f) => readFileSync(f, 'utf8')).join('\n');
}

const explained = readFileSync(join(__dirname, 'route-reasons.txt'), 'utf8')
  .split('\n')
  .filter((l) => l.trim() && !l.startsWith('#'))
  .map((l) => l.trim().split(/\s+/).slice(0, 2).join(' ').replace(' /api/', ' /'));

describe('every served route is used or explained', () => {
  it('has a caller in apps/web or a line in route-reasons.txt', () => {
    const client = clientPaths();
    const PUBLIC = /^(GET|POST) \/(webhooks|healthz|metrics|v\d+)\b/;
    const unused = servedRoutes().filter((r) => {
      if (PUBLIC.test(r) || explained.includes(r)) return false;
      const path = r.split(' ')[1].slice(1).replace(/:[^/]+/g, '');
      return !client.includes(path.split('/')[0]);
    });
    expect(unused).toEqual([]);
  });
});
