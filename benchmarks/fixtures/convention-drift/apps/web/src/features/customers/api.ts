import { apiClient } from '@acme/http';

export type Customer = { id: string; name: string; email: string };

export function fetchCustomer(id: string): Promise<Customer> {
  return apiClient.get(`customers/${id}`).json<Customer>();
}
