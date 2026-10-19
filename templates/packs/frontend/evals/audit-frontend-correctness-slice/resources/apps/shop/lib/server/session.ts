import { getSession } from './account';

// The signed-in customer for the request being rendered, so deep components need not thread it through props.
let currentCustomer: { customerId: string; name: string } | null = null;

export async function loadCustomer() {
  currentCustomer = await getSession();
  return currentCustomer;
}

export function customer() {
  return currentCustomer;
}
