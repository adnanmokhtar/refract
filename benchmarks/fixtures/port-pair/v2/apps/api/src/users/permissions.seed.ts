// Role → permission map seeded into V2 (V1: spatie roles/permissions tables, dot names).
export const ROLE_PERMISSIONS: Record<string, string[]> = {
  admin: ['*'],
  manager: ['orders:view', 'orders:create', 'orders:update', 'orders:export', 'invoices:view', 'invoices:issue', 'wallets:view', 'wallets:adjust', 'reports:view', 'account:update', 'stock:import', 'stock:reserve'],
  agent: ['orders:view', 'invoices:view', 'wallets:view'],
  clerk: ['orders:view', 'orders:create', 'orders:update', 'invoices:view', 'wallets:view', 'stock:reserve'],
};
