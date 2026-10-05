import { faker } from '@faker-js/faker';

const orders = Array.from({ length: 40 }, (_, i) => ({
  id: `o_${i}`,
  number: `HM-${1000 + i}`,
  customer: faker.person.fullName(),
  status: 'placed',
  eta: faker.date.soon().toISOString(),
}));

export const mockApi = {
  get: async (url: string) => ({ data: url.includes('orders') ? orders : [] }),
  post: async () => ({ data: {} }),
  patch: async () => ({ data: {} }),
  delete: async () => ({ data: {} }),
};
