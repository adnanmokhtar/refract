import { db } from '../db';

export const audit = {
  record: (event: string, fields: Record<string, unknown>) =>
    db.query('INSERT INTO audit_log (event, fields) VALUES ($1, $2)', [event, JSON.stringify(fields)]),
};
