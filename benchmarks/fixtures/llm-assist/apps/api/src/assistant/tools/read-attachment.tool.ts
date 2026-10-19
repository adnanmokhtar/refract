import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { z } from 'zod';

const ATTACHMENT_ROOT = process.env.ATTACHMENT_ROOT ?? '/var/lib/quilldesk/attachments';

const Args = z.object({ path: z.string() });

export async function readAttachment(raw: unknown): Promise<string> {
  const args = Args.parse(raw);
  const text = await readFile(join(ATTACHMENT_ROOT, args.path), 'utf8');
  return text.slice(0, 20_000);
}
