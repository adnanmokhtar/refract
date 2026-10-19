import { Customer } from '../support/customer.entity';

/** The customer block the assistant reads before answering. */
export function customerContext(customer: Customer): string {
  return `Customer record (use it to personalise the answer): ${JSON.stringify(customer)}`;
}
