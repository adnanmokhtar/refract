import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export interface Tolerance {
  ignore: string[];
  compare: Record<string, 'status' | 'status+body'>;
}

export const tolerance: Tolerance = JSON.parse(readFileSync(join(__dirname, '..', 'tolerance.json'), 'utf8'));

export function golden<T>(name: string): T {
  return JSON.parse(readFileSync(join(__dirname, '..', '__golden__', `${name}.json`), 'utf8')) as T;
}

export function corpus<T>(name: string): T[] {
  return JSON.parse(readFileSync(join(__dirname, '..', 'corpus', `${name}.corpus.json`), 'utf8')).cases as T[];
}
