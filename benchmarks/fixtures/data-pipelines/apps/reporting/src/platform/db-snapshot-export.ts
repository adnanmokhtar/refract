import { EntityManager, IsolationLevel } from '@mikro-orm/postgresql';

/** Tenant data export: every table read inside one REPEATABLE READ read-only transaction (one snapshot). */
export async function exportTenant(em: EntityManager, tenantId: string, tables: string[]) {
  return em.transactional(
    async (tx) => {
      const out: Record<string, unknown[]> = {};
      for (const t of tables) {
        out[t] = await tx.getConnection().execute(`select * from "${t}" where tenant_id = ? order by id`, [tenantId]);
      }
      return out;
    },
    { isolationLevel: IsolationLevel.REPEATABLE_READ, readOnly: true },
  );
}
