import { EntityManager } from '@mikro-orm/postgresql';

export interface CustomerRow {
  id: string;
  phoneKey: string;
  displayName: string;
}

/** Caller-ID lookup for the phone-order desk: normalised phone key → customer, one tenant at a time. */
export async function customerIndex(em: EntityManager, tenantId: string): Promise<Map<string, CustomerRow>> {
  const rows = await em
    .getConnection()
    .execute<CustomerRow[]>('SELECT id, phone_key AS "phoneKey", display_name AS "displayName" FROM customers WHERE tenant_id = ?', [tenantId]);
  return new Map(rows.map((c) => [c.phoneKey, c]));
}
