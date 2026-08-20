// Minimal message catalogue. Keys are dot-scoped by feature.

const messages: Record<string, string> = {
  'orders.title': 'Orders',
  'orders.search.placeholder': 'Search orders',
  'orders.empty': 'No orders match this filter',
  'orders.error': 'Could not load orders',
  'orders.column.reference': 'Reference',
  'orders.column.customer': 'Customer',
  'orders.column.status': 'Status',
  'orders.column.total': 'Total',
  'orders.action.refund': 'Refund order',
  'orders.action.export': 'Export',
  'customers.title': 'Customers',
  'customers.empty': 'No customers yet',
  'customers.error': 'Could not load customers',
  'customers.avatarAlt': 'Profile photo',
  'common.retry': 'Try again',
  'common.close': 'Close',
  'common.loading': 'Loading',
};

export function t(key: string): string {
  return messages[key] ?? key;
}
