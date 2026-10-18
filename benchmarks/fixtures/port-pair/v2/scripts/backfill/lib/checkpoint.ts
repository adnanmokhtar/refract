import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export interface Checkpoint {
  table: string;
  last_id: number;
  mapping_version: number;
  started_at: string;
}

const dir = join(import.meta.dirname, '..', 'state');

// Resumes from the recorded id. The caller decides whether the recorded mapping_version still
// matches its mapper; a mapping change mid-window means a re-backfill from 0 (DM-13).
export function readCheckpoint(key: string): Checkpoint | null {
  const file = join(dir, `${key}.checkpoint.json`);
  return existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as Checkpoint) : null;
}

export function writeCheckpoint(key: string, value: Checkpoint): void {
  writeFileSync(join(dir, `${key}.checkpoint.json`), `${JSON.stringify(value)}\n`);
}
