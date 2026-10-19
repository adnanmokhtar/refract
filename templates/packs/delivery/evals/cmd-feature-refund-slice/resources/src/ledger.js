// The money ledger: every movement of money is one entry, per tenant, append-only.

import { nextId } from './store.js';

export function recordEntry(store, tenantId, entry) {
  const entries = store.ledger.get(tenantId) ?? [];
  const row = { id: nextId(store, 'led'), at: new Date().toISOString(), ...entry };
  entries.push(row);
  store.ledger.set(tenantId, entries);
  return row;
}

export function listEntries(store, tenantId, filter = {}) {
  return (store.ledger.get(tenantId) ?? []).filter((entry) =>
    Object.entries(filter).every(([key, value]) => entry[key] === value),
  );
}
