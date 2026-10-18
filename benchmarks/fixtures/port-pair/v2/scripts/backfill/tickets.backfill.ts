import { randomUUID } from 'node:crypto';
import { runChunked } from './lib/runner';
import type { Source } from './lib/source';
import type { Target } from './lib/target';
import { fromV1Local } from './lib/time';

// ADR-0010: soft-deleted V1 tickets are archived to cold storage and never shown again, so they
// are filtered at the source on purpose and never reach V2.
const SOURCE_FILTER = 'deleted_at IS NULL';

interface V1Ticket {
  id: number;
  account_id: number;
  subject: string;
  body: string;
  status: string;
  priority: number;
  assignee_id: number | null;
  opened_by: number;
  due_at: string | null;
  closed_at: string | null;
  created_at: string;
}

export function mapTicket(row: V1Ticket) {
  return {
    id: randomUUID(),
    account_id: row.account_id,
    subject: row.subject,
    body: row.body,
    status: row.status,
    priority: row.priority,
    assignee_id: row.assignee_id,
    opened_by: row.opened_by,
    due_at: fromV1Local(row.due_at),
    closed_at: fromV1Local(row.closed_at),
    created_at: fromV1Local(row.created_at),
  };
}

export async function backfillTickets(source: Source, target: Target): Promise<number> {
  return runChunked<V1Ticket>(source, { table: 'tickets', where: SOURCE_FILTER, checkpointKey: null, batch: 5000, sleepMs: 0 }, async (rows) => {
    await target.insert('tickets', rows.map(mapTicket));
  });
}
