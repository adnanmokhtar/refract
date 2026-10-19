/** Chart of accounts as the API returns it: every account with its parent's id (null for top-level). */
export interface Account {
  id: string;
  parentId: string | null;
  name: string;
}

export interface FlatAccountRow {
  id: string;
  parentId: string | null;
  name: string;
  depth: number;
}

/** Rows for the indented accounts table, each parent followed by its children. */
export function flattenAccountTree(accounts: Account[]): FlatAccountRow[] {
  const byParent = new Map<string | null, Account[]>();
  for (const a of accounts) {
    const siblings = byParent.get(a.parentId);
    if (siblings) siblings.push(a);
    else byParent.set(a.parentId, [a]);
  }
  const rows: FlatAccountRow[] = [];
  const visit = (parentId: string | null, depth: number): void => {
    for (const a of byParent.get(parentId) ?? []) {
      rows.push({ id: a.id, parentId: a.parentId, name: a.name, depth });
      visit(a.id, depth + 1);
    }
  };
  visit(null, 0);
  return rows;
}
