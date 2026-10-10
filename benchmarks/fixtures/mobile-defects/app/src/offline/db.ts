import * as SQLite from 'expo-sqlite';

export const db = SQLite.openDatabaseSync('pantrygo.db');

db.execSync(`
  CREATE TABLE IF NOT EXISTS order_queue (
    id TEXT PRIMARY KEY NOT NULL,
    kind TEXT NOT NULL,
    path TEXT NOT NULL,
    payload TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at INTEGER NOT NULL
  );
`);

export type QueuedOrder = {
  id: string;
  kind: 'create' | 'amend' | 'cancel';
  path: string;
  payload: string;
  idempotency_key: string;
  attempts: number;
  status: 'pending' | 'failed';
  created_at: number;
};
